#!/usr/bin/env bash

set -euo pipefail

portal_source=$1
dispatcher_source=$2
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/resolved" "$test_dir/state"

sed \
  -e "s|/run/systemd/resolved.conf.d|$test_dir/resolved|g" \
  -e "s|/run/manage-dns-portal|$test_dir/state|g" \
  "$portal_source" > "$test_dir/portal.sh"
sed "s|/run/manage-dns-portal|$test_dir/state|g" \
  "$dispatcher_source" > "$test_dir/dispatcher.sh"

printf '#!%s\n' "$(command -v bash)" > "$test_dir/bin/id"
cat >> "$test_dir/bin/id" <<'EOF'
[[ $1 == -u ]] && echo 0
EOF

printf '#!%s\n' "$(command -v bash)" > "$test_dir/bin/nmcli"
cat >> "$test_dir/bin/nmcli" <<'EOF'
case "$*" in
  '-t -f DEVICE,TYPE,STATE device status')
    if [[ ${MOCK_WIFI:-yes} == yes ]]; then
      echo 'wlp5s0:wifi:connected'
    fi
    ;;
  '-g GENERAL.CON-UUID device show wlp5s0')
    echo 'wifi-uuid'
    ;;
  '-g IP4.DNS,IP6.DNS device show wlp5s0')
    echo '192.0.2.1'
    ;;
  *) exit 1 ;;
esac
EOF

printf '#!%s\n' "$(command -v bash)" > "$test_dir/bin/systemctl"
cat >> "$test_dir/bin/systemctl" <<'EOF'
case "$*" in
  'is-active --quiet tailscaled.service' | 'is-active --quiet manage-dns-portal.service')
    exit 0
    ;;
  'is-system-running')
    echo "${MOCK_SYSTEM_STATE:-running}"
    ;;
  'reload systemd-resolved.service')
    echo reload >> "$MOCK_LOG"
    if [[ -e $MOCK_FAIL_RELOAD ]]; then
      rm "$MOCK_FAIL_RELOAD"
      exit 1
    fi
    ;;
  '--no-block stop manage-dns-portal.service')
    echo stop >> "$MOCK_LOG"
    ;;
  *) exit 1 ;;
esac
EOF

printf '#!%s\n' "$(command -v bash)" > "$test_dir/bin/tailscale"
cat >> "$test_dir/bin/tailscale" <<'EOF'
case "$1" in
  status)
    printf '{"BackendState":"%s"}\n' "$(cat "$MOCK_TAILSCALE_STATE")"
    ;;
  down | up)
    echo "$1" >> "$MOCK_LOG"
    if [[ $1 == down ]]; then
      echo Stopped > "$MOCK_TAILSCALE_STATE"
    else
      echo Running > "$MOCK_TAILSCALE_STATE"
    fi
    ;;
  *) exit 1 ;;
esac
EOF

chmod +x "$test_dir/bin/"*
export PATH="$test_dir/bin:$PATH"
export MOCK_LOG="$test_dir/commands"
export MOCK_TAILSCALE_STATE="$test_dir/tailscale-state"
export MOCK_FAIL_RELOAD="$test_dir/fail-reload"
dropin="$test_dir/resolved/99-captive-portal.conf"

echo Running > "$MOCK_TAILSCALE_STATE"
bash "$test_dir/portal.sh" start
test -e "$dropin"
test "$(cat "$MOCK_TAILSCALE_STATE")" = Stopped
test "$(cat "$test_dir/state/connection-uuid")" = wifi-uuid
grep -qx 'DNS=' "$dropin"
grep -qx 'Domains=' "$dropin"
grep -qx 'DNSOverTLS=no' "$dropin"
grep -qx 'DNSSEC=no' "$dropin"

CONNECTION_UUID=wifi-uuid bash "$test_dir/dispatcher.sh" wlp5s0 up
test "$(grep -c '^stop$' "$MOCK_LOG" || true)" = 0
CONNECTION_UUID=other-uuid bash "$test_dir/dispatcher.sh" wlp5s0 up
test "$(grep -c '^stop$' "$MOCK_LOG")" = 1

bash "$test_dir/portal.sh" stop
test ! -e "$dropin"
test "$(cat "$MOCK_TAILSCALE_STATE")" = Running
test "$(grep -c '^down$' "$MOCK_LOG")" = 1
test "$(grep -c '^up$' "$MOCK_LOG")" = 1

: > "$MOCK_LOG"
echo Running > "$MOCK_TAILSCALE_STATE"
bash "$test_dir/portal.sh" start
MOCK_SYSTEM_STATE=stopping bash "$test_dir/portal.sh" stop
test ! -e "$dropin"
test "$(cat "$MOCK_TAILSCALE_STATE")" = Stopped
test "$(grep -c '^up$' "$MOCK_LOG" || true)" = 0

: > "$MOCK_LOG"
echo Stopped > "$MOCK_TAILSCALE_STATE"
bash "$test_dir/portal.sh" start
bash "$test_dir/portal.sh" stop
test ! -e "$dropin"
test "$(grep -Ec '^(up|down)$' "$MOCK_LOG" || true)" = 0

: > "$MOCK_LOG"
echo Running > "$MOCK_TAILSCALE_STATE"
touch "$MOCK_FAIL_RELOAD"
if bash "$test_dir/portal.sh" start; then
  echo 'Portal mode unexpectedly survived a resolver reload failure' >&2
  exit 1
fi
test ! -e "$dropin"
test "$(cat "$MOCK_TAILSCALE_STATE")" = Running
test "$(grep -c '^down$' "$MOCK_LOG")" = 1
test "$(grep -c '^up$' "$MOCK_LOG")" = 1

: > "$MOCK_LOG"
if MOCK_WIFI=no bash "$test_dir/portal.sh" start; then
  echo 'Portal mode unexpectedly started without Wi-Fi' >&2
  exit 1
fi
test ! -e "$dropin"
test ! -s "$MOCK_LOG"

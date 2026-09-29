#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

dropin_dir=/run/systemd/resolved.conf.d
dropin="$dropin_dir/99-captive-portal.conf"
state_dir=/run/manage-dns-portal
portal_temporary_file=''
portal_tailscale_stopped=false
portal_dropin_installed=false

if [[ $(id -u) -ne 0 ]]; then
  echo "manage-dns-portal must run as root" >&2
  exit 1
fi

start_portal_mode() {
  local iface connection_uuid dns_servers tailscale_state

  if [[ -e "$dropin" ]]; then
    echo "Captive portal DNS drop-in already exists: $dropin" >&2
    return 1
  fi

  iface="$(nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }')"
  if [[ -z "$iface" ]]; then
    echo "No connected NetworkManager Wi-Fi device found" >&2
    return 1
  fi

  connection_uuid="$(nmcli -g GENERAL.CON-UUID device show "$iface")"
  dns_servers="$(nmcli -g IP4.DNS,IP6.DNS device show "$iface")"
  if [[ -z "$connection_uuid" || -z "$dns_servers" ]]; then
    echo "Wi-Fi connection $iface has no connection UUID or DNS servers" >&2
    return 1
  fi

  tailscale_state=Stopped
  if systemctl is-active --quiet tailscaled.service; then
    tailscale_state="$(tailscale status --json | jq -er '.BackendState | strings')"
  fi

  install -d -m 0755 "$dropin_dir"
  install -d -m 0700 "$state_dir"
  printf '%s\n' "$connection_uuid" > "$state_dir/connection-uuid"
  printf '%s\n' "$tailscale_state" > "$state_dir/tailscale-state"

  rollback() {
    local result=$?
    trap - EXIT
    if [[ $result -ne 0 ]]; then
      if [[ -n "$portal_temporary_file" ]]; then
        rm -f "$portal_temporary_file"
      fi
      if [[ $portal_dropin_installed == true ]]; then
        rm -f "$dropin"
        if ! systemctl reload systemd-resolved.service; then
          echo "Failed to restore systemd-resolved after portal mode error" >&2
        fi
      fi
      if [[ $portal_tailscale_stopped == true ]] && ! tailscale up; then
        echo "Failed to restore Tailscale after portal mode error" >&2
      fi
    fi
    return "$result"
  }
  trap rollback EXIT

  portal_temporary_file="$(mktemp "$dropin_dir/.99-captive-portal.conf.XXXXXX")"
  cat > "$portal_temporary_file" <<'EOF'
[Resolve]
DNS=
Domains=
DNSOverTLS=no
DNSSEC=no
EOF
  chmod 0644 "$portal_temporary_file"

  if [[ $tailscale_state == Running ]]; then
    portal_tailscale_stopped=true
    tailscale down
  fi

  mv -f "$portal_temporary_file" "$dropin"
  portal_dropin_installed=true
  systemctl reload systemd-resolved.service
  trap - EXIT
  echo "Captive portal DNS mode enabled on $iface"
}

stop_portal_mode() {
  local tailscale_state=Stopped failed=0

  if [[ $(systemctl is-system-running || true) == stopping ]]; then
    rm -f "$dropin"
    return 0
  fi

  if [[ -r "$state_dir/tailscale-state" ]]; then
    tailscale_state="$(cat "$state_dir/tailscale-state")"
  else
    echo "Missing portal mode state; Tailscale state cannot be restored automatically" >&2
    failed=1
  fi

  rm -f "$dropin"
  if ! systemctl reload systemd-resolved.service; then
    echo "Failed to restore private DNS configuration" >&2
    failed=1
  fi

  if [[ $tailscale_state == Running ]]; then
    if ! tailscale up; then
      echo "Failed to restore Tailscale" >&2
      failed=1
    fi
  fi

  if [[ $failed -eq 0 ]]; then
    echo "Captive portal DNS mode disabled"
  else
    echo "Captive portal DNS mode cleanup was incomplete" >&2
  fi
  return "$failed"
}

if [[ $# -ne 1 ]]; then
  echo "Usage: manage-dns-portal {start|stop}" >&2
  exit 2
fi

case "$1" in
  start) start_portal_mode ;;
  stop) stop_portal_mode ;;
  *)
    echo "Usage: manage-dns-portal {start|stop}" >&2
    exit 2
    ;;
esac

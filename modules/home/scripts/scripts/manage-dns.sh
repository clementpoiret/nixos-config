#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: manage-dns {disable|enable|status}" >&2
  exit 2
fi

case "$1" in
  disable)
    run0 -- systemctl start manage-dns-portal.service
    ;;
  enable)
    run0 -- systemctl stop manage-dns-portal.service
    ;;
  status)
    if [[ -e /run/systemd/resolved.conf.d/99-captive-portal.conf ]]; then
      echo "Captive portal DNS mode is active."
    else
      echo "Private DNS mode is active."
    fi
    resolvectl status
    ;;
  *)
    echo "Usage: manage-dns {disable|enable|status}" >&2
    exit 2
    ;;
esac

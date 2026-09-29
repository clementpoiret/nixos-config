#!/usr/bin/env bash

set -euo pipefail

if [[ ${2:-} != up || -z ${CONNECTION_UUID:-} ]]; then
  exit 0
fi

if ! systemctl is-active --quiet manage-dns-portal.service; then
  exit 0
fi

state_file=/run/manage-dns-portal/connection-uuid
if [[ ! -r "$state_file" || $(cat "$state_file") != "$CONNECTION_UUID" ]]; then
  systemctl --no-block stop manage-dns-portal.service
fi

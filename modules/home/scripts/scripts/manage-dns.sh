#!/usr/bin/env bash
#
# Script to temporarily switch to DHCP-provided DNS for captive portal login
# on a NixOS system using systemd-resolved.

set -euo pipefail

# --- Configuration ---
get_active_interface() {
  local iface
  # Try to get the interface for the default route to a public IP
  iface=$(ip route get 8.8.8.8 2>/dev/null | awk -F 'dev ' '{print $2}' | awk '{print $1}')

  if [[ -z "$iface" ]]; then
    # Fallback: Get the first connected device from NetworkManager
    iface=$(
      nmcli --color no --terse --fields DEVICE,STATE dev status |
        grep -E ':(connected|conectado|verbunden|connecté)$' |
        cut -d: -f1 |
        head -n 1
    )
  fi

  if [[ -z "$iface" ]]; then
    echo "Error: Could not determine an active network interface." >&2
    return 1
  fi
  echo "$iface"
  return 0
}

# --- Script Actions ---
action_disable_private_dns() {
  local interface
  interface=$(get_active_interface)
  if [[ $? -ne 0 ]]; then
    exit 1
  fi
  echo "Using interface: $interface"

  local dhcp_dns_servers
  # Get DHCP-provided DNS servers from NetworkManager for the active interface.
  # Process to ensure a clean, space-separated list of IPs.
  dhcp_dns_servers=$(
    nmcli -g IP4.DNS dev show "$interface" | # Get raw output (could be multi-line or single line with pipes)
    tr '\n' ' ' |                            # Convert all newlines to spaces (ensures one line)
    sed 's/\s*|\s*/ /g' |                    # Replace ' | ' (pipe with optional surrounding spaces) with a single space
    awk '{$1=$1};1'                          # Normalize all spaces (leading/trailing/multiple to single)
  )

  if [[ -z "$dhcp_dns_servers" ]]; then
    echo "Warning: Could not retrieve DHCP-provided DNS servers for '$interface'." >&2
    echo "Attempting to disable DoT and set domain '~.' only for '$interface'."
    echo "systemd-resolved might still pick up DHCP DNS if available from NM."
    if sudo resolvectl dnsovertls "$interface" no && \
       sudo resolvectl domain "$interface" '~.'; then
      echo "Successfully disabled DoT and set routing domain for '$interface'."
      echo "If this still fails, DHCP might not be providing DNS, or another issue exists."
    else
      echo "Error: Failed to set DoT/domain for '$interface' via resolvectl." >&2
      exit 1
    fi
  else
    echo "Temporarily setting DNS for interface '$interface' to: $dhcp_dns_servers"
    echo "Disabling DNS-over-TLS for this interface."
    echo "Setting search domain to '~.' to prioritize these settings for all lookups on this interface."

    if sudo resolvectl dns "$interface" $dhcp_dns_servers && \
       sudo resolvectl dnsovertls "$interface" no && \
       sudo resolvectl domain "$interface" '~.'; then
      echo "Successfully configured '$interface' to use DNS: $dhcp_dns_servers (DoT disabled) for all domains."
    else
      echo "Error: Failed to configure DNS/DoT/domain for '$interface' via resolvectl." >&2
      sudo resolvectl revert "$interface" 2>/dev/null
      exit 1
    fi
  fi

  echo "You should now be able to access the captive portal."
  echo "After logging in, run: $0 enable"
  # sudo resolvectl flush-caches
  # echo "DNS caches flushed."
}

action_enable_private_dns() {
  local interface
  interface=$(get_active_interface)
  if [[ $? -ne 0 ]]; then
    echo "No active interface found to revert. If settings were applied to an" >&2
    echo "interface that is now down, 'sudo resolvectl revert <iface_name>'" >&2
    echo "might be needed manually, or simply reconnecting the interface." >&2
    exit 1
  fi
  echo "Using interface: $interface"

  echo "Restoring default DNS settings for interface '$interface'."
  if sudo resolvectl revert "$interface"; then
    echo "DNS settings for '$interface' reverted."
    echo "Your private DNS configuration should now be active for this interface."
  else
    echo "Warning: 'resolvectl revert' for '$interface' failed or did nothing." >&2
    echo "This can happen if settings were already default." >&2
  fi
  # sudo resolvectl flush-caches
  # echo "DNS caches flushed."
}

# --- Main Logic ---
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 [disable|enable]" >&2
  exit 1
fi

case "$1" in
  disable)
    action_disable_private_dns
    ;;
  enable)
    action_enable_private_dns
    ;;
  *)
    echo "Invalid action: $1" >&2
    echo "Usage: $0 [disable|enable]" >&2
    exit 1
    ;;
esac

exit 0

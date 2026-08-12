{ config, ... }:
{
  services.tailscale = {
    enable = true;
  };

  networking.firewall = {
    # Allow Tailscale's transport globally, but do not trust the whole mesh.
    allowedUDPPorts = [ config.services.tailscale.port ];
    interfaces."tailscale0" = {
      allowedTCPPorts = [
        22
        22000
      ];
      allowedUDPPorts = [ 22000 ];
    };
  };

  systemd = {
    services = {
      tailscaled.serviceConfig.Environment = [
        "TS_DEBUG_FIREWALL_MODE=nftables"
      ];
      NetworkManager-wait-online.enable = false;
    };
    network.wait-online.enable = false;
  };
  boot.initrd.systemd.network.wait-online.enable = false;
}

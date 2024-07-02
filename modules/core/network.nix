{ pkgs, host, inputs, ... }:
let
  secrets = import "${inputs.secrets}/variables.nix";
in
{
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    nameservers = [
      secrets.dot."${host}"
    ];
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 59010 59011 ];
      allowedUDPPorts = [ 59010 59011 ];
      # allowedUDPPortRanges = [
        # { from = 4000; to = 4007; }
        # { from = 8000; to = 8010; }
      # ];
    };
  };

  environment.systemPackages = with pkgs; [
    networkmanagerapplet
  ];

  services.resolved = {
    enable = true;
    dnsovertls = "true";
  };
}

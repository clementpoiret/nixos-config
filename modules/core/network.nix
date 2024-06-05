{ pkgs, host, inputs, ... }:
let
  secrets = import "${inputs.secrets}/variables.nix";
in
{
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    nameservers = [
      "45.90.28.0#NixOS--${host}-${secrets.nextdnsId}.dns.nextdns.io"
      "45.90.30.0#NixOS--${host}-${secrets.nextdnsId}.dns.nextdns.io"
      "2a07:a8c0::#NixOS--${host}-${secrets.nextdnsId}.dns.nextdns.io"
      "2a07:a8c1::#NixOS--${host}-${secrets.nextdnsId}.dns.nextdns.io"
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

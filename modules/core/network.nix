{ config, pkgs, host, inputs, ... }:
let nameservers = builtins.readFile "/run/user/1000/secrets/dns/${host}";
in {
  networking = {
    hostName = "${host}";
    networkmanager.enable = true;
    nameservers = [ nameservers ];
    #nameservers = [ "1.1.1.1" ];
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

  environment.systemPackages = with pkgs; [ networkmanagerapplet ];

  services.resolved = {
    enable = true;
    dnsovertls = "true";
  };
}

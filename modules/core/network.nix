{ pkgs, host, ... }:
{
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
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

  #services.resolved = {
  #  enable = true;
  #};

  #classified = {
  #  targetDir = "/etc/systemd/";
  #  keys = {
  #    primary = "/home/clementpoiret/.config/classified/primary.key";
  #  };

  #  files = {
  #    "resolved.conf" = {
  #      key = "primary";
  #      encrypted = ../../secrets/desktop/resolved.conf;
  #      # Default is `400`
  #      mode = "777";
  #      # Defaults are `root:root`
  #      # user = "nginx";
  #      # group = "nogroup";
  #    };
  #  };
  #};

}

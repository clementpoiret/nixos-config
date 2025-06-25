{
  pkgs,
  host,
  ...
}:
let
  nameserver = builtins.readFile "/run/user/1000/secrets/dns/${host}";
in
{
  networking = {
    hostName = "${host}";
    networkmanager.enable = true;
    nameservers = [ nameserver ];
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        80
        443
        59010
        59011
      ];
      allowedUDPPorts = [
        59010
        59011
      ];
      # allowedUDPPortRanges = [
      # { from = 4000; to = 4007; }
      # { from = 8000; to = 8010; }
      # ];
    };
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  environment.systemPackages = with pkgs; [ networkmanagerapplet ];

  services.resolved = {
    enable = true;
    dnsovertls = "true";
  };
}

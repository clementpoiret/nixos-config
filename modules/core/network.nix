{
  config,
  pkgs,
  host,
  ...
}:
let
  nameserver = builtins.readFile config.sops.secrets."dns/${host}".path;
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
        51820
        59010
        59011
      ];
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
    settings = {
      Resolve = {
        DNSoverTLS = "true";
      };
    };
  };
}

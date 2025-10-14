{
  config,
  pkgs,
  host,
  ...
}:
let
  nameserver = builtins.readFile config.sops.secrets."dns/${host}".path;

  addr1 = builtins.readFile config.sops.secrets."vpn/${host}/interface/address1".path;
  addr2 = builtins.readFile config.sops.secrets."vpn/${host}/interface/address2".path;
  dns1 = builtins.readFile config.sops.secrets."vpn/${host}/interface/dns1".path;
  dns2 = builtins.readFile config.sops.secrets."vpn/${host}/interface/dns2".path;

  alip1 = builtins.readFile config.sops.secrets."vpn/${host}/peer/allowedIP1".path;
  alip2 = builtins.readFile config.sops.secrets."vpn/${host}/peer/allowedIP2".path;
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

    wg-quick.interfaces = {
      wg0 = {
        address = [
          addr1
          addr2
        ];

        dns = [
          dns1
          dns2
        ];

        privateKeyFile = config.sops.secrets."vpn/${host}/interface/privateKey".path;

        peers = [
          {
            publicKey = builtins.readFile config.sops.secrets."vpn/${host}/peer/publicKey".path;
            presharedKeyFile = config.sops.secrets."vpn/${host}/peer/presharedKey".path;

            allowedIPs = [
              alip1
              alip2
            ];

            endpoint = builtins.readFile config.sops.secrets."vpn/${host}/peer/endpoint".path;

            # Helpful behind NAT
            persistentKeepalive = 25;
          }
        ];
      };
    };
  };

  systemd.services.wg-quick-wg0 = {
    after = [
      "network-online.target"
      "nss-lookup.target"
    ];
    wants = [ "network-online.target" ];
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

{
  config,
  pkgs,
  host,
  ...
}:
let
  nameserver = builtins.readFile config.sops.secrets."dns/${host}".path;

  privateKey = builtins.readFile config.sops.secrets."vpn/${host}/interface/privateKey".path;
  addr1 = builtins.readFile config.sops.secrets."vpn/${host}/interface/address1".path;
  addr2 = builtins.readFile config.sops.secrets."vpn/${host}/interface/address2".path;
  dns1 = builtins.readFile config.sops.secrets."vpn/${host}/interface/dns1".path;
  dns2 = builtins.readFile config.sops.secrets."vpn/${host}/interface/dns2".path;

  publicKey = builtins.readFile config.sops.secrets."vpn/${host}/peer/publicKey".path;
  presharedKey = builtins.readFile config.sops.secrets."vpn/${host}/peer/presharedKey".path;
  endpoint = builtins.readFile config.sops.secrets."vpn/${host}/peer/endpoint".path;
  alips = builtins.readFile config.sops.secrets."vpn/${host}/peer/allowedIPs".path;
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

    networkmanager.ensureProfiles.profiles = {
      wg0 = {
        connection = {
          id = "vpn.rhizome-labs.com";
          type = "wireguard";
          autoconnect = false;
          interface-name = "wg0";
        };

        wireguard = {
          private-key = privateKey;
          private-key-flags = 0;
        };

        "wireguard-peer.${publicKey}" = {
          endpoint = endpoint;
          preshared-key = presharedKey;
          preshared-key-flags = 0;
          allowed-ips = alips;
          persistent-keepalive = 25;
        };

        ipv4 = {
          method = "manual";
          address1 = addr1;
          dns = dns1;
        };
        ipv6 = {
          method = "manual";
          address1 = addr2;
          dns = dns2;
        };
      };
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

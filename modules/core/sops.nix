{
  config,
  inputs,
  pkgs,
  host,
  ...
}:
{
  environment.systemPackages = with pkgs; [ sops ];
  imports = [ inputs.sops-nix.nixosModules.sops ];
  sops = {
    age.keyFile = "/home/clementpoiret/.config/sops/age/keys.txt";

    defaultSopsFile = ../../secrets/user-secrets.yaml;

    secrets = {
      "dns/${host}".mode = "0444";

      "vpn/${host}/interface/privateKey".mode = "0400";
      "vpn/${host}/interface/address1".mode = "0444";
      "vpn/${host}/interface/address2".mode = "0444";
      "vpn/${host}/interface/dns1".mode = "0444";
      "vpn/${host}/interface/dns2".mode = "0444";

      "vpn/${host}/peer/publicKey".mode = "0444";
      "vpn/${host}/peer/presharedKey".mode = "0400";
      "vpn/${host}/peer/allowedIP1".mode = "0444";
      "vpn/${host}/peer/allowedIP2".mode = "0444";
      "vpn/${host}/peer/endpoint".mode = "0444";
    };
  };
}

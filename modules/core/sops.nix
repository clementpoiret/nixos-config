{
  inputs,
  pkgs,
  host,
  ...
}:
{
  environment.systemPackages = with pkgs; [ sops ];
  imports = [ inputs.sops-nix.nixosModules.sops ];
  sops = {
    age.keyFile = "/root/.config/sops/age/keys.txt";

    defaultSopsFile = ../../secrets/user-secrets.yaml;

    secrets = {
      "dns/${host}".mode = "0400";
      "wireguard/vps_public_key".mode = "0400";
      "wireguard/vps_ip".mode = "0400";
    };
  };
}

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
      "dns/${host}".mode = "0444";
    };
  };
}

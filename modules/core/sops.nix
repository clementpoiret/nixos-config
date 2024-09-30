{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ sops ];
  # imports = [ inputs.sops-nix.nixosModules.sops ];
  # sops = {
  #   age.keyFile = "/home/clementpoiret/.config/sops/age/keys.txt";

  #   secrets."dns/${host}" = {
  #     sopsFile = ../../secrets/secrets.yaml;
  #     owner = config.users.users.clementpoiret.name;
  #   };
  # };
}

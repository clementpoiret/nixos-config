{ inputs, host, ... }:
let secretFile = ../../secrets/user-secrets.yaml;
in {
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    age.keyFile = "/home/clementpoiret/.config/sops/age/keys.txt";

    defaultSymlinkPath = "/run/user/1000/secrets";
    defaultSecretsMountPoint = "/run/user/1000/secrets.d";

    secrets."dns/${host}" = { sopsFile = secretFile; };
    secrets."api_keys/anthropic" = { sopsFile = secretFile; };
    secrets."api_keys/pypi" = { sopsFile = secretFile; };
  };
}

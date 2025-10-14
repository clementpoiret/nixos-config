{ inputs, host, ... }:
let
  secretFile = ../../secrets/user-secrets.yaml;
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    age.keyFile = "/home/clementpoiret/.config/sops/age/keys.txt";

    defaultSymlinkPath = "/run/user/1000/secrets";
    defaultSecretsMountPoint = "/run/user/1000/secrets.d";

    secrets = {
      "dns/${host}" = {
        sopsFile = secretFile;
      };

      "api_keys/anthropic".sopsFile = secretFile;
      "api_keys/deepseek".sopsFile = secretFile;
      "api_keys/pypi".sopsFile = secretFile;

      "hostnames/vpsrhizome".sopsFile = secretFile;
      "hostnames/vpspers".sopsFile = secretFile;
      "hostnames/rpihome".sopsFile = secretFile;
      "hostnames/jz".sopsFile = secretFile;
      "hostusers/default".sopsFile = secretFile;
      "hostusers/jz".sopsFile = secretFile;
    };
  };

  home.sessionVariables = {
    ANTHROPIC_API_KEY = builtins.readFile /run/user/1000/secrets/api_keys/anthropic;
    CLAUDE_API_KEY = builtins.readFile /run/user/1000/secrets/api_keys/anthropic;
  };
}

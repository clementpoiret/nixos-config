{
  config,
  inputs,
  host,
  ...
}:
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    age.keyFile = "/home/clementpoiret/.config/sops/age/keys.txt";

    defaultSopsFile = ../../secrets/user-secrets.yaml;

    secrets = {
      "api_keys/anthropic" = { };
      "api_keys/deepseek" = { };
      "api_keys/pypi" = { };

      "hostnames/vpsrhizome" = { };
      "hostnames/vpspers" = { };
      "hostnames/rpihome" = { };
      "hostnames/jz" = { };
      "hostusers/default" = { };
      "hostusers/jz" = { };
    };
  };

  home.sessionVariables = {
    # ANTHROPIC_API_KEY = builtins.readFile /run/user/1000/secrets/api_keys/anthropic;
    ANTHROPIC_API_KEY = builtins.readFile config.sops.secrets."api_keys/anthropic".path;
    CLAUDE_API_KEY = builtins.readFile config.sops.secrets."api_keys/anthropic".path;
  };
}

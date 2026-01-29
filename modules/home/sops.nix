{
  config,
  inputs,
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
      "hostnames/bastion" = { };
      "hostnames/jz" = { };
      "hostnames/jzpp" = { };
      "hostusers/default" = { };
      "hostusers/bastion" = { };
      "hostusers/jz" = { };

      "accounts/realName" = { };
      "accounts/pers1/name" = { };
      "accounts/pers1/address" = { };
      "accounts/pers1/userName" = { };
      "accounts/pers1/imap/host" = { };
      "accounts/pers1/imap/port" = { };
      "accounts/pers1/smtp/host" = { };
      "accounts/pers1/smtp/port" = { };
      "accounts/pers1/passwordCommand" = { };
      "accounts/pers2/name" = { };
      "accounts/pers2/address" = { };
      "accounts/pers2/userName" = { };
      "accounts/pers2/imap/host" = { };
      "accounts/pers2/imap/port" = { };
      "accounts/pers2/smtp/host" = { };
      "accounts/pers2/smtp/port" = { };
      "accounts/pers2/passwordCommand" = { };
      "accounts/pers3/name" = { };
      "accounts/pers3/address" = { };
      "accounts/pers3/userName" = { };
      "accounts/pers3/imap/host" = { };
      "accounts/pers3/imap/port" = { };
      "accounts/pers3/smtp/host" = { };
      "accounts/pers3/smtp/port" = { };
      "accounts/pers3/passwordCommand" = { };
      "accounts/work1/name" = { };
      "accounts/work1/address" = { };
      "accounts/work1/userName" = { };
      "accounts/work1/imap/host" = { };
      "accounts/work1/imap/port" = { };
      "accounts/work1/smtp/host" = { };
      "accounts/work1/smtp/port" = { };
      "accounts/work1/passwordCommand" = { };
    };
  };

  home.sessionVariables = {
    # ANTHROPIC_API_KEY = builtins.readFile /run/user/1000/secrets/api_keys/anthropic;
    ANTHROPIC_API_KEY = builtins.readFile config.sops.secrets."api_keys/anthropic".path;
    CLAUDE_API_KEY = builtins.readFile config.sops.secrets."api_keys/anthropic".path;
  };
}

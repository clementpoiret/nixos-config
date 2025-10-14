{
  config,
  lib,
  ...
}:
let
  jzHostName = builtins.readFile config.sops.secrets."hostnames/jz".path;
  rpihomeHostName = builtins.readFile config.sops.secrets."hostnames/rpihome".path;
  vpspersHostName = builtins.readFile config.sops.secrets."hostnames/vpspers".path;
  vpsrhizomeHostName = builtins.readFile config.sops.secrets."hostnames/vpsrhizome".path;

  defaultUser = builtins.readFile config.sops.secrets."hostusers/default".path;
  jzUser = builtins.readFile config.sops.secrets."hostusers/jz".path;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        identityAgent = "none"; # bypass agent everywhere
        identitiesOnly = true;
        addKeysToAgent = "no";
        identityFile = [
          "~/.ssh/id_ed25519_sk_yk1"
          "~/.ssh/id_ed25519_sk_yk2"
        ];

        # Connection multiplexing: one auth reused by many commands
        controlMaster = "auto";
        controlPersist = "15m";
        controlPath = "~/.ssh/cm/%r@%h:%p";
        serverAliveInterval = 30;
        serverAliveCountMax = 6;

        # Misc
        user = defaultUser;
      };

      "github.com" = {
        hostname = "github.com";
        user = "git";
      };

      "jz" = {
        hostname = jzHostName;
        user = jzUser;
      };

      "rpihome" = {
        hostname = rpihomeHostName;
      };

      "vpspers" = {
        hostname = vpspersHostName;
      };

      "vpsrhizome" = {
        hostname = vpsrhizomeHostName;
      };
    };
  };

  home.activation.ensureSshCmDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -d -m 700 "${config.home.homeDirectory}/.ssh/cm"
  '';

  services.ssh-agent.enable = true;
}

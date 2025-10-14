{
  config,
  lib,
  ...
}:
let
  jzHostName = builtins.readFile "/run/user/1000/secrets/hostnames/jz";
  rpihomeHostName = builtins.readFile "/run/user/1000/secrets/hostnames/rpihome";
  vpspersHostName = builtins.readFile "/run/user/1000/secrets/hostnames/vpspers";
  vpsrhizomeHostName = builtins.readFile "/run/user/1000/secrets/hostnames/vpsrhizome";

  defaultUser = builtins.readFile "/run/user/1000/secrets/hostusers/default";
  jzUser = builtins.readFile "/run/user/1000/secrets/hostusers/jz";
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

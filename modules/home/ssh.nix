{
  config,
  lib,
  pkgs,
  ...
}:
let
  bastionHostName = builtins.readFile config.sops.secrets."hostnames/bastion".path;
  jzHostName = builtins.readFile config.sops.secrets."hostnames/jz".path;
  jzppHostName = builtins.readFile config.sops.secrets."hostnames/jzpp".path;
  rpihomeHostName = builtins.readFile config.sops.secrets."hostnames/rpihome".path;
  vpspersHostName = builtins.readFile config.sops.secrets."hostnames/vpspers".path;
  vpsrhizomeHostName = builtins.readFile config.sops.secrets."hostnames/vpsrhizome".path;

  defaultUser = builtins.readFile config.sops.secrets."hostusers/default".path;
  bastionUser = builtins.readFile config.sops.secrets."hostusers/bastion".path;
  jzUser = builtins.readFile config.sops.secrets."hostusers/jz".path;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    package = pkgs.openssh_hpn;

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
        controlPath = "/dev/shm/%r@%h:%p";
        serverAliveInterval = 30;
        serverAliveCountMax = 6;

        # Misc
        user = defaultUser;
      };

      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
        user = "git";
      };

      "jz" = {
        hostname = jzHostName;
        user = jzUser;
        proxyJump = "bastion";
      };
      "jzpp" = {
        hostname = jzppHostName;
        user = jzUser;
        proxyJump = "bastion";
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

      "bastion" = {
        hostname = bastionHostName;
        user = bastionUser;
        port = 443;
      };
    };
  };

  home.activation.ensureSshCmDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -d -m 700 "${config.home.homeDirectory}/.ssh/cm"
  '';

  services.ssh-agent.enable = true;
}

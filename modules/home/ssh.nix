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
  bootUser = builtins.readFile config.sops.secrets."hostusers/defaultBoot".path;
  bastionUser = builtins.readFile config.sops.secrets."hostusers/bastion".path;
  jzUser = builtins.readFile config.sops.secrets."hostusers/jz".path;

  vpsPersPort = builtins.fromJSON (builtins.readFile config.sops.secrets."ports/vpspersboot".path);
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
        controlPath = "~/.ssh/sockets/%C";
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
      "gitlab.com" = {
        hostname = "altssh.gitlab.com";
        port = 443;
        user = "git";
      };

      "jz" = {
        hostname = jzHostName;
        user = jzUser;
        proxyJump = "bastion";
        setEnv = {
          TERM = "xterm-256color";
        };
      };
      "jzpp" = {
        hostname = jzppHostName;
        user = jzUser;
        proxyJump = "bastion";
        setEnv = {
          TERM = "xterm-256color";
        };
      };

      "rpihome" = {
        hostname = rpihomeHostName;
      };

      "vpspersboot" = {
        user = bootUser;
        hostname = vpspersHostName;
        identityFile = "~/.ssh/id_ed25519_initramfs";
        port = vpsPersPort;
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
        setEnv = {
          TERM = "xterm-256color";
        };
      };
    };
  };

  systemd.user.tmpfiles.rules = [
    # Type  Path              Mode  User  Group  Age  Argument
    "d      %h/.ssh/sockets   0700  -     -      -    -"
  ];

  home.activation.ensureSshCmDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -d -m 700 "${config.home.homeDirectory}/.ssh/cm"
  '';

  services.ssh-agent.enable = true;
}

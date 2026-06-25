{
  config,
  lib,
  pkgs,
  ...
}:
let
  secretPath = name: config.sops.secrets.${name}.path;

  writeSshSecretConfig = pkgs.writeShellScript "write-ssh-secret-config" ''
    set -eu

    read_secret() {
      tr -d '\r\n' < "$1"
    }

    install -d -m 700 "''${HOME}/.ssh"
    target="''${HOME}/.ssh/config.secrets"
    tmp="''${target}.tmp"

    cat > "$tmp" <<EOF
    Host jz
      HostName $(read_secret ${lib.escapeShellArg (secretPath "hostnames/jz")})
      User $(read_secret ${lib.escapeShellArg (secretPath "hostusers/jz")})
      ProxyJump bastion
      SetEnv TERM="xterm-256color"

    Host jzpp
      HostName $(read_secret ${lib.escapeShellArg (secretPath "hostnames/jzpp")})
      User $(read_secret ${lib.escapeShellArg (secretPath "hostusers/jz")})
      ProxyJump bastion
      SetEnv TERM="xterm-256color"

    Host rpihome
      HostName $(read_secret ${lib.escapeShellArg (secretPath "hostnames/rpihome")})

    Host vpspersboot
      User $(read_secret ${lib.escapeShellArg (secretPath "hostusers/defaultBoot")})
      HostName $(read_secret ${lib.escapeShellArg (secretPath "hostnames/vpspers")})
      IdentityFile ~/.ssh/id_ed25519_initramfs
      Port $(read_secret ${lib.escapeShellArg (secretPath "ports/vpspersboot")})

    Host vpspers
      HostName $(read_secret ${lib.escapeShellArg (secretPath "hostnames/vpspers")})

    Host vpsrhizome
      HostName $(read_secret ${lib.escapeShellArg (secretPath "hostnames/vpsrhizome")})

    Host bastion
      HostName $(read_secret ${lib.escapeShellArg (secretPath "hostnames/bastion")})
      User $(read_secret ${lib.escapeShellArg (secretPath "hostusers/bastion")})
      Port 443
      SetEnv TERM="xterm-256color"

    Host *
      User $(read_secret ${lib.escapeShellArg (secretPath "hostusers/default")})
    EOF

    chmod 600 "$tmp"
    mv "$tmp" "$target"
  '';
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    package = pkgs.openssh_hpn;
    extraConfig = "Include ~/.ssh/config.secrets";

    settings = {
      "*" = {
        IdentityAgent = "none"; # bypass agent everywhere
        IdentitiesOnly = true;
        AddKeysToAgent = "no";
        IdentityFile = [
          "~/.ssh/id_ed25519_sk_yk1"
          "~/.ssh/id_ed25519_sk_yk2"
        ];

        # Connection multiplexing: one auth reused by many commands
        ControlMaster = "auto";
        ControlPersist = "15m";
        ControlPath = "~/.ssh/sockets/%C";
        ServerAliveInterval = 30;
        ServerAliveCountMax = 6;
      };

      "github.com" = {
        HostName = "ssh.github.com";
        Port = 443;
        User = "git";
      };
      "gitlab.com" = {
        HostName = "altssh.gitlab.com";
        Port = 443;
        User = "git";
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

  systemd.user.services.write-ssh-secret-config = {
    Unit = {
      Description = "Write SSH config generated from sops secrets";
      After = [ "sops-nix.service" ];
      Requires = [ "sops-nix.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${writeSshSecretConfig}";
    };
    Install.WantedBy = [ "default.target" ];
  };

  services.ssh-agent.enable = true;
}

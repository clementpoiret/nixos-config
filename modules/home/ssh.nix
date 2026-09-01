{
  config,
  host,
  lib,
  pkgs,
  ...
}:
let
  secretPath = name: config.sops.secrets.${name}.path;
  forwardedGpgHome = "${config.home.homeDirectory}/.gnupg-forwarded";
  forwardedPeer = if host == "desktop" then "laptop" else "desktop";
  forwardedAlias = "${forwardedPeer}-forwarded";
  identityFiles =
    if host == "desktop" then
      [
        "${config.home.homeDirectory}/.ssh/id_ed25519_sk_yk2"
        "${config.home.homeDirectory}/.ssh/id_ed25519_sk_yk1"
      ]
    else
      [
        "${config.home.homeDirectory}/.ssh/id_ed25519_sk_yk1"
        "${config.home.homeDirectory}/.ssh/id_ed25519_sk_yk2"
      ];
  forwardedDestinations = [
    "git@[ssh.github.com]:443"
    "git@[altssh.gitlab.com]:443"
    "${forwardedPeer}>git@[ssh.github.com]:443"
    "${forwardedPeer}>git@[altssh.gitlab.com]:443"
  ];
  loadConstrainedSshKeys = pkgs.writeShellScript "load-constrained-ssh-keys" ''
    set -eu

    export SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR}/ssh-agent"
    exec ${pkgs.openssh_hpn}/bin/ssh-add \
      ${
        lib.concatMapStringsSep " \\\n      " (
          destination: "-h ${lib.escapeShellArg destination}"
        ) forwardedDestinations
      } \
      ${lib.concatMapStringsSep " \\\n      " lib.escapeShellArg identityFiles}
  '';
  sshAgentAskpass = pkgs.writeShellScript "ssh-agent-askpass" ''
    set -eu

    if manager_environment="$(${pkgs.systemd}/bin/systemctl --user show-environment)"; then
      while IFS= read -r variable; do
        case "$variable" in
          DISPLAY=*|WAYLAND_DISPLAY=*|XDG_CURRENT_DESKTOP=*|XDG_SESSION_TYPE=*|DBUS_SESSION_BUS_ADDRESS=*)
            export "$variable"
            ;;
        esac
      done <<< "$manager_environment"
    fi

    exec ${pkgs.seahorse}/libexec/seahorse/ssh-askpass "$@"
  '';

  writeSshSecretConfig = pkgs.writeShellScript "write-ssh-secret-config" ''
    set -eu

    read_secret() {
      tr -d '\r\n' < "$1"
    }

    install -d -m 700 "''${HOME}/.ssh"
    target="''${HOME}/.ssh/config.secrets"
    tmp="''${target}.tmp"
    forwarded_gpg_socket="$(${pkgs.gnupg}/bin/gpgconf \
      --homedir ${lib.escapeShellArg forwardedGpgHome} --list-dir agent-socket)"
    local_gpg_extra_socket="$(${pkgs.gnupg}/bin/gpgconf --list-dir agent-extra-socket)"

    cat > "$tmp" <<EOF
    Host ${forwardedAlias}
      HostName ${forwardedPeer}
      ForwardAgent \''${SSH_AUTH_SOCK}
      RemoteForward $forwarded_gpg_socket $local_gpg_extra_socket
      SetEnv GNUPGHOME=${forwardedGpgHome}
      ExitOnForwardFailure yes
      ControlMaster no
      ControlPersist no
      ControlPath none

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

    Host leo leonardo
      HostName $(read_secret ${lib.escapeShellArg (secretPath "hostnames/leo")})
      User $(read_secret ${lib.escapeShellArg (secretPath "hostusers/leo")})
      IdentityAgent SSH_AUTH_SOCK
      IdentityFile none
      IdentitiesOnly no

    Host leo-data leonardo-data
      HostName $(read_secret ${lib.escapeShellArg (secretPath "hostnames/leo-data")})
      User $(read_secret ${lib.escapeShellArg (secretPath "hostusers/leo")})
      IdentityAgent SSH_AUTH_SOCK
      IdentityFile none
      IdentitiesOnly no

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

    Host * !github.com !gitlab.com
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
    includes = [ "~/.ssh/config.secrets" ];

    settings = {
      defaultAuth = {
        header = "Host * !github.com !gitlab.com !leo !leonardo !leo-data !leonardo-data";
        IdentityAgent = "none"; # bypass agent everywhere
        IdentitiesOnly = true;
        IdentityFile = map (file: "~/.ssh/${builtins.baseNameOf file}") identityFiles;
      };

      "*" = {
        AddKeysToAgent = "no";

        # Connection multiplexing: one auth reused by many commands
        ControlMaster = "auto";
        ControlPersist = "15m";
        ControlPath = "~/.ssh/sockets/%C";
        ServerAliveInterval = 30;
        ServerAliveCountMax = 6;
      };

      "github.com" = lib.hm.dag.entryBefore [ "defaultAuth" ] {
        HostName = "ssh.github.com";
        Port = 443;
        User = "git";
        IdentityAgent = "SSH_AUTH_SOCK";
        IdentityFile = "none";
        IdentitiesOnly = false;
      };
      "gitlab.com" = lib.hm.dag.entryBefore [ "defaultAuth" ] {
        HostName = "altssh.gitlab.com";
        Port = 443;
        User = "git";
        IdentityAgent = "SSH_AUTH_SOCK";
        IdentityFile = "none";
        IdentitiesOnly = false;
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
  systemd.user.services.ssh-agent.Service = {
    ExecStartPost = "${loadConstrainedSshKeys}";
    Environment = [
      "SSH_ASKPASS=${sshAgentAskpass}"
      "SSH_ASKPASS_REQUIRE=force"
    ];
  };
}

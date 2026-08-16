{
  config,
  host ? null,
  lib,
  pkgs,
  username ? null,
  ...
}:
let
  cfg = config.security.localAppArmor;
  stateType = lib.types.enum [
    "disable"
    "complain"
    "enforce"
  ];

  homeDirectory = "/home/${username}";
  syncthingRoot = lib.removeSuffix "/" config.services.syncthing.dataDir;
  syncthingRoots = [ syncthingRoot ] ++ lib.optional (host == "desktop") "/srv/syncthing";

  softmakerOffice = pkgs.softmaker-office-nx.override {
    officeVersion = {
      version = "1502";
      edition = "";
      hash = "sha256-24CnmZ5lnx7+NvZxiAgib0uYCfUQuUgRuVW+K6AeB3U=";
    };
  };

  homePackages =
    if
      username != null
      && lib.hasAttrByPath [
        "home-manager"
        "users"
        username
        "home"
        "packages"
      ] config
    then
      config.home-manager.users.${username}.home.packages
    else
      [ ];
  codexDesktopPackages = builtins.filter (
    package: lib.hasPrefix "codex-desktop-" (lib.getName package)
  ) homePackages;

  appProfiles = [
    {
      name = "file-roller";
      package = pkgs.file-roller;
      executable = "file-roller";
    }
    {
      name = "evince";
      package = pkgs.evince;
      executable = "evince";
    }
    {
      name = "mpv";
      package = pkgs.mpv;
      executable = "mpv";
    }
    {
      name = "pqiv";
      package = pkgs.pqiv;
      executable = "pqiv";
    }
    {
      name = "inkscape";
      package = pkgs.inkscape;
      executable = "inkscape";
    }
    {
      name = "drawio";
      package = pkgs.drawio;
      executable = "drawio";
      userns = true;
    }
    {
      name = "zotero";
      package = pkgs.zotero;
      executable = "zotero";
      userns = true;
    }
    {
      name = "logseq";
      package = pkgs.logseq-appimage;
      executable = "logseq-appimage";
      userns = true;
    }
    {
      name = "textmaker";
      package = softmakerOffice;
      executable = "softmaker-office-nx-textmaker";
    }
    {
      name = "planmaker";
      package = softmakerOffice;
      executable = "softmaker-office-nx-planmaker";
    }
    {
      name = "presentations";
      package = softmakerOffice;
      executable = "softmaker-office-nx-presentations";
    }
    {
      name = "brave";
      package = pkgs.brave;
      executable = "brave";
      userns = true;
    }
    {
      name = "glide";
      package = pkgs.flake.glide-browser;
      executable = "glide";
      userns = true;
    }
    # {
    #   name = "helium";
    #   package = pkgs.flake.helium;
    #   executable = "helium";
    #   userns = true;
    # }
    {
      name = "mullvad-browser";
      package = pkgs.mullvad-browser;
      executable = "mullvad-browser";
      userns = true;
    }
    # {
    #   name = "orion";
    #   package = pkgs.flake.orion-browser;
    #   executable = "orion-browser";
    #   userns = true;
    # }
    {
      name = "vivaldi";
      package = pkgs.vivaldi;
      executable = "vivaldi";
      userns = true;
    }
    {
      name = "thunderbird";
      package = pkgs.thunderbird;
      executable = "thunderbird";
      userns = true;
    }
    {
      name = "protonmail-bridge";
      package = pkgs.protonmail-bridge;
      executable = "protonmail-bridge";
    }
    {
      name = "proton-pass";
      package = pkgs.proton-pass;
      executable = "proton-pass";
      userns = true;
    }
    {
      name = "proton-pass-cli";
      package = pkgs.proton-pass-cli;
      executable = "pass-cli";
    }
    {
      name = "proton-vpn";
      package = pkgs.proton-vpn;
      executable = "protonvpn-app";
    }
    {
      name = "qbittorrent";
      package = pkgs.qbittorrent;
      executable = "qbittorrent";
    }
    {
      name = "motrix";
      package = pkgs.motrix-next;
      executable = "motrix-next";
      userns = true;
    }
    {
      name = "deezer";
      package = pkgs.deezer-enhanced;
      executable = "deezer-enhanced";
      userns = true;
    }
    {
      name = "codex-cli";
      package = pkgs.flake.codex-cli;
      executable = "codex";
      developer = true;
    }
    {
      name = "claude-code";
      package = pkgs.flake.claude-code;
      executable = "claude";
      developer = true;
    }
    # {
    #   name = "antigravity-cli";
    #   package = pkgs.flake.antigravity-cli;
    #   executable = "agy";
    #   developer = true;
    # }
    # {
    #   name = "antigravity-ide";
    #   package = pkgs.flake.antigravity-ide;
    #   executable = "antigravity-ide";
    #   developer = true;
    #   userns = true;
    # }
    # {
    #   name = "zed";
    #   package = pkgs.zed-editor;
    #   executable = "zeditor";
    #   developer = true;
    #   userns = true;
    # }
  ]
  ++ lib.optionals (codexDesktopPackages != [ ]) [
    {
      name = "codex-desktop";
      package = builtins.head codexDesktopPackages;
      executable = "codex-desktop";
      developer = true;
      userns = true;
    }
  ];

  serviceProfileNames = [
    "local-apply-secret-dns"
    "local-syncthing"
  ];
  appProfileNames = map (app: "local-${app.name}") appProfiles;
  managedProfileNames = serviceProfileNames ++ appProfileNames;

  stateFor =
    name:
    cfg.profileOverrides.${name} or (
      if cfg.mode == "staged" then
        if name == "local-apply-secret-dns" then "enforce" else "complain"
      else
        cfg.mode
    );

  secretDenials = ''
    audit deny owner @{HOME}/.config/sops/age/keys.txt rwklm,
    audit deny owner @{HOME}/.config/sops-nix/secrets{,/**} rwklm,
    audit deny owner @{HOME}/.gnupg/private-keys-v1.d/{,**} rwklm,
    audit deny owner @{HOME}/.gnupg/secring.gpg rwklm,
    audit deny owner @{HOME}/.password-store/{,**} rwklm,
    audit deny owner @{HOME}/.local/share/password-store/{,**} rwklm,
    audit deny owner @{HOME}/.ssh/id_{dsa,ecdsa,ed25519,rsa} rwklm,
    audit deny owner @{HOME}/.ssh/*.{key,p12,pem,pfx} rwklm,
    audit deny owner @{HOME}/.config/Yubico/u2f_keys rwklm,
    audit deny owner /run/user/[0-9]*/secrets.d/{,**} rwklm,
    audit deny /run/secrets/{,**} rwklm,
  '';

  sharedApplicationRules = ''
    include <abstractions/base>
    include <abstractions/nameservice>
    include <abstractions/ssl_certs>
    include <abstractions/fonts>
    include <abstractions/audio>
    include <abstractions/X>
    include <abstractions/wayland>
    include <abstractions/dconf>
    include <abstractions/xdg-desktop>
    include <abstractions/opengl>

    network,
    dbus,
    signal,
    unix,

    /etc/{,**} r,
    /proc/{,**} r,
    /sys/{,**} r,
    /dev/dri/{,**} rw,
    /dev/snd/{,**} rw,
    /dev/video[0-9]* rw,
    /dev/shm/{,**} rwkl,
    owner /tmp/{,**} rwkl,
    owner /var/tmp/{,**} rwkl,
    owner /run/user/[0-9]*/{,**} rwkl,
    owner @{HOME}/ r,
    owner @{HOME}/** rwkl,
  '';

  developerTools = with pkgs; [
    bash
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    git
    jujutsu
    nix
    openssh_hpn
    seahorse
    ripgrep
    fd
    gcc
    gnumake
    cmake
    python3
    nodejs
    uv
    gh
    helix
    neovim
  ];

  applicationPolicy =
    app:
    let
      profileName = "local-${app.name}";
      state = stateFor profileName;
      executable = "${app.package}/bin/${app.executable}";
      closureRoots = [ app.package ] ++ lib.optionals (app.developer or false) developerTools;
      closureRules = pkgs.apparmorRulesFromClosure {
        name = profileName;
        additionalRules = [ "$path/bin/** ixr" ];
      } closureRoots;
    in
    {
      name = profileName;
      value = {
        inherit state;
        profile = ''
          abi <abi/4.0>,
          include <tunables/global>

          profile ${profileName} ${executable} flags=(attach_disconnected,mediate_deleted) {
            ${sharedApplicationRules}
            include "${closureRules}"
            ${lib.optionalString (app.userns or false) "userns,"}
            ${lib.optionalString (app.developer or false) ''
              ptrace,
              owner @{HOME}/** ix,
              owner /tmp/** ix,
              owner /var/tmp/** ix,
            ''}
            ${lib.optionalString (state == "enforce" && !(app.developer or false)) secretDenials}
          }
        '';
      };
    };

  syncthingPathRules = lib.concatMapStringsSep "\n" (path: ''
    ${path}/ r,
    ${path}/** rwkl,
  '') syncthingRoots;
  syncthingPolicy = {
    state = stateFor "local-syncthing";
    profile = ''
      abi <abi/4.0>,
      include <tunables/global>

      profile local-syncthing flags=(attach_disconnected,mediate_deleted) {
        include <abstractions/base>
        include <abstractions/nameservice>
        include <abstractions/ssl_certs>
        include "${
          pkgs.apparmorRulesFromClosure {
            name = "local-syncthing";
            additionalRules = [ "$path/bin/** ixr" ];
          } pkgs.syncthing
        }"

        network,
        signal,
        unix,
        /etc/{,**} r,
        /proc/{,**} r,
        /sys/{,**} r,
        /run/{,**} r,
        /run/syncthing/{,**} rwkl,
        owner /tmp/{,**} rwkl,
        ${homeDirectory}/ r,
        ${syncthingPathRules}
      }
    '';
  };
  dnsPolicy = {
    state = stateFor "local-apply-secret-dns";
    profile = ''
      abi <abi/4.0>,
      include <tunables/global>

      profile local-apply-secret-dns flags=(attach_disconnected,mediate_deleted) {
        include <abstractions/base>
        include <abstractions/nameservice>
        include "${
          pkgs.apparmorRulesFromClosure
            {
              name = "local-apply-secret-dns";
              additionalRules = [ "$path/bin/** ixr" ];
            }
            [
              pkgs.bash
              pkgs.coreutils
              pkgs.gnused
              pkgs.systemd
            ]
        }"

        signal,
        unix,
        dbus,
        capability chown,
        /dev/tty rw,
        /nix/store/*-unit-script-apply-secret-dns-start/bin/apply-secret-dns-start rix,
        /run/secrets/dns/{,**} r,
        /run/systemd/resolve/{,**} rw,
        /run/systemd/resolved.conf.d/ rw,
        /run/systemd/resolved.conf.d/** rw,
        /run/systemd/private rw,
        /run/dbus/system_bus_socket rw,
      }
    '';
  };
in
{
  options.security.localAppArmor = {
    mode = lib.mkOption {
      type = lib.types.enum [
        "staged"
        "disable"
        "complain"
        "enforce"
      ];
      default = "staged";
      description = ''
        Default state for the locally managed AppArmor profiles. Staged mode
        enforces the DNS helper and loads every other profile in complain mode.
      '';
    };

    profileOverrides = lib.mkOption {
      type = lib.types.attrsOf stateType;
      default = { };
      description = "Per-profile state overrides for locally managed AppArmor policies.";
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.all (name: lib.elem name managedProfileNames) (
          builtins.attrNames cfg.profileOverrides
        );
        message = ''
          security.localAppArmor.profileOverrides contains an unmanaged profile.
          Managed profiles: ${lib.concatStringsSep ", " managedProfileNames}
        '';
      }
    ];

    security.apparmor = {
      enable = true;
      enableCache = false;
      killUnconfinedConfinables = false;
      policies = builtins.listToAttrs (map applicationPolicy appProfiles) // {
        local-syncthing = syncthingPolicy;
        local-apply-secret-dns = dnsPolicy;
      };
    };

    systemd.services.syncthing = {
      after = lib.optional (stateFor "local-syncthing" != "disable") "apparmor.service";
      requires = lib.optional (stateFor "local-syncthing" != "disable") "apparmor.service";
      serviceConfig = {
        AppArmorProfile = lib.mkIf (stateFor "local-syncthing" != "disable") "local-syncthing";
        ProtectHome = "read-only";
        ProtectSystem = "strict";
        ReadWritePaths = syncthingRoots;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };

    systemd.services.apply-secret-dns = {
      after = lib.optional (stateFor "local-apply-secret-dns" != "disable") "apparmor.service";
      requires = lib.optional (stateFor "local-apply-secret-dns" != "disable") "apparmor.service";
      serviceConfig.AppArmorProfile = lib.mkIf (
        stateFor "local-apply-secret-dns" != "disable"
      ) "local-apply-secret-dns";
    };
  };
}

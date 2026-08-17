{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  softmakerOffice = pkgs.softmaker-office-nx.override {
    officeVersion = {
      version = "1502";
      edition = "";
      hash = "sha256-24CnmZ5lnx7+NvZxiAgib0uYCfUQuUgRuVW+K6AeB3U=";
    };
  };

  desktopCapabilities = [
    "desktop"
    "portal"
    "session-bus"
  ];
  documentDesktopCapabilities = desktopCapabilities ++ [ "user-files" ];
  acceleratedDesktopCapabilities = desktopCapabilities ++ [ "gpu" ];
  acceleratedDocumentCapabilities = acceleratedDesktopCapabilities ++ [ "user-files" ];
  electronCapabilities = acceleratedDesktopCapabilities ++ [
    "network"
    "runtime-introspection"
    "shared-memory"
    "userns"
  ];
  electronDocumentCapabilities = electronCapabilities ++ [ "user-files" ];
  browserCapabilities = electronCapabilities ++ [
    "audio"
    "camera"
    "credential-broker"
    "user-files"
  ];
  archiveExecutionPackages = with pkgs; [
    bzip2
    cpio
    gnutar
    gzip
    lz4
    unzip
    xz
  ];

  codexDesktopPackages = builtins.filter (
    package: lib.hasPrefix "codex-desktop-" (lib.getName package)
  ) config.home.packages;
  codexDesktopPackage =
    if builtins.length codexDesktopPackages == 1 then builtins.head codexDesktopPackages else null;
in
{
  imports = [
    inputs.codex-desktop-linux.homeManagerModules.default
  ];

  home.packages = (
    with pkgs;
    [
      # General Utilities
      # bitwise # CLI tool for bit/hex manipulation
      # bleachbit # Disk space cleaner and privacy tool
      ast-grep
      bluetuith # Bluetooth device management
      # cliphist # Wayland clipboard history manager
      # dconf-editor # Graphical editor for dconf database
      dust # Intuitive disk usage analyzer (improved du)
      entr # Run commands when files change
      fd # Simple, fast alternative to 'find'
      file # Determine file type
      file-roller # Archive viewer
      fzf # Command-line fuzzy finder
      # gtt # Google Translate terminal interface (TUI)
      gtrash # Move files to trash instead of permanent delete
      # hexdump # Display files in hex/decimal/octal
      killall # Terminate processes by name
      # kdePackages.ksshaskpass # askpass replacement
      # lazysql # Like lazygit, but for sql
      lsd # Modern ls with colors/icons
      lz4 # Extremely fast lossless compression
      man-pages # Additional manual pages
      nautilus # File manager
      ncdu # Disk usage analyzer with ncurses interface
      nitch # System information fetch utility
      pamixer # PulseAudio CLI mixer
      pavucontrol # PulseAudio volume control GUI
      playerctl # Media player controller
      pqiv # Powerful X11 image viewer
      # qalculate-gtk # Advanced calculator (GTK interface)
      ripgrep # grep replacement
      runapp # faster uwsm-app replacement
      serpl # SerpAPI CLI for search engine results
      # syshud # OSD
      tldr # Simplified community-driven man pages
      # toipe # Terminal typing test
      unzip # Extract ZIP archives
      via # Keyboard layout configuration tool
      wl-clipboard # Wayland clipboard utilities
      wormhole-william # magic wormhole in Go
      # xxd # Hexdump/reverse hexdump utility
      zenity

      # System Information & Monitoring
      dmidecode # DMI/SMBIOS table decoder
      inxi # Comprehensive system information tool
      lshw # Hardware detection and listing
      pciutils # PCI bus configuration tools

      # Disk & Filesystems
      exfat # exFAT filesystem utilities
      gparted # Partition editor GUI

      # Networking
      aria2 # Multi-source command-line download utility
      motrix-next # dl manager
      protonmail-bridge
      # protonmail-bridge-gui
      # protonvpn-cli # ProtonVPN command-line interface
      proton-vpn # ProtonVPN graphical interface
      rclone # Cloud storage synchronization
      sshfs
      wget # Non-interactive network downloader

      # Development Tools
      cmake # Cross-platform build system
      devenv # Reproducible development environments with Nix
      gcc # GNU Compiler Collection
      gnumake # GNU make build automation
      nixfmt # nix formatter
      rustfmt # Rust code formatter
      # secretspec # Secret env vars for devenv
      shfmt # Shell script formatter
      zig # General-purpose programming language/toolchain

      # Scientific writing
      # typst
      typst
      typstyle
      tinymist
      typst-live

      # Language Servers
      # basedpyright # Python language server (Pyright-based)
      ltex-ls-plus
      marksman
      nixd # Nix language server
      ruff # Python LSP
      # rust-analyzer # Rust language server
      ty
      # vscode-extensions.vadimcn.vscode-lldb # VS Code LLDB debugger extension
      # zls # Zig language server

      # Package Management
      nix-prefetch-github # Prefetch GitHub repository hashes for Nix
      uv # Python package installer/resolver (Astral)

      # Version Control
      gh # GitHub CLI
      # gh-dash # GitHub CLI dashboard
      glab # GitLab CLI
      hub # GitHub-focused wrapper for git

      # Containers & Orchestration
      # docker # Container runtime
      # google-cloud-sdk-gce
      fluxcd # Continuous delivery for Kubernetes
      k9s # Kubernetes CLI interface
      kubernetes-helm # Kubernetes package manager
      kubectl # Kubernetes command-line client

      # Infrastructure as Code
      opentofu # Open-source Terraform-compatible IaC
      terraform # Infrastructure as Code tool (HashiCorp)
      terraform-ls # Terraform language server

      # Browsers
      brave # Privacy-focused web browser
      # firefox-devedition # Firefox Developer Edition
      # glide.glide-browser # Keyboard-focused browser
      flake.glide-browser # Keyboard-focused browser
      # flake.helium
      mullvad-browser
      # flake.orion-browser
      vivaldi # Feature-rich web browser
      vivaldi-ffmpeg-codecs # Vivaldi media codecs

      # Graphics
      gifsicle # GIF image manipulation
      # graphviz # Graph visualization software
      inkscape # Vector graphics editor

      # Multimedia
      ffmpeg # Multimedia framework
      mpv # Media player

      # Office & Documents
      drawio # Diagrams editor
      evince # PDF/document viewer
      hugo # Static site generator
      hunspell # Spell checker engine
      hunspellDicts.fr-any # French Hunspell dictionary
      # libreoffice-fresh # Office suite
      # onlyoffice-desktopeditors # Office suite
      pdftk # PDF document manipulation toolkit
      poppler # PDF rendering library (CLI tools)
      # softmaker-office-nx # Office suite
      softmakerOffice
      tdf # Terminal PDF reader
      zotero # Reference management

      # Security
      age # Simple modern file encryption
      gcr
      openssl # SSL/TLS protocol implementation
      proton-pass # Password manager
      proton-pass-cli # CLI version :)
      sops # Encrypted secrets management
      step-cli # X509, OAuth, JWT, OATH OTP, etc

      # Communication
      # signal-desktop-bin # Signal messaging client
      # zoom-us # Video conferencing client

      # Webcam stuff
      guvcview
      v4l-utils

      # Miscellaneous
      # anytype
      bibiman # Bibliography management CLI
      # flake.antigravity-cli
      # flake.antigravity-ide
      flake.claude-code
      flake.codex-cli
      deezer-enhanced
      dstask
      # flake.gemini-cli # Gemini protocol client
      # libation # Extract audio books
      libnotify # Desktop notification library
      logseq-appimage # Manually using AppImage because plugins are broken in the nixpkgs version
      # poweralertd # Power alert daemon (low battery/etc.)
      qbittorrent
      qmk
      # todoman # todo list
      # ventoy
      wiper # Secure file deletion tool
      xdg-utils # Desktop integration scripts (open/mailto)
      yubioath-flutter # Yubico Authenticator
      yubikey-manager # Manage yubikeys :)
    ]
  );

  programs.codexDesktopLinux = {
    enable = true;
    # remoteControl = {
    #   enable = true;
    #   package = pkgs.flake.codex-cli;
    # };
    # remoteMobileControl.enable = true;
    linuxFeatures = [
      "appshots"
      "remote-control-ui"
      "remote-mobile-control"
      "node-repl-reaper"
    ];
    # cliPackage = pkgs.flake.codex-cli;
  };

  assertions = [
    {
      assertion = builtins.length codexDesktopPackages == 1;
      message = ''
        programs.codexDesktopLinux must install exactly one codex-desktop package;
        found ${toString (builtins.length codexDesktopPackages)} candidates.
      '';
    }
  ];

  localAppArmor = {
    applications = {
      file-roller = {
        package = pkgs.file-roller;
        capabilities = documentDesktopCapabilities;
        extraClosureRoots = archiveExecutionPackages;
        executionPackages = archiveExecutionPackages;
        homePaths = [ ".config/file-roller" ];
      };
      evince = {
        package = pkgs.evince;
        capabilities = acceleratedDocumentCapabilities;
        homePaths = [ ".config/evince" ];
      };
      mpv = {
        package = pkgs.mpv;
        capabilities = acceleratedDocumentCapabilities ++ [
          "audio"
          "network"
        ];
        homePaths = [
          ".cache/mpv"
          ".config/mpv"
        ];
      };
      pqiv = {
        package = pkgs.pqiv;
        capabilities = acceleratedDocumentCapabilities;
        homePaths = [ ".config/pqiv" ];
      };
      inkscape = {
        package = pkgs.inkscape;
        capabilities = acceleratedDocumentCapabilities;
        homePaths = [
          ".cache/inkscape"
          ".config/inkscape"
        ];
      };
      drawio = {
        package = pkgs.drawio;
        capabilities = electronDocumentCapabilities;
        executionPackages = [ pkgs.electron ];
        namespaceExecutables = [ "${pkgs.electron}/bin/electron" ];
        namespaceRules = ''
          capability sys_admin,
          capability sys_ptrace,
          owner /proc/[0-9]*/{gid_map,setgroups,uid_map} w,
        '';
        homePaths = [
          ".cache/drawio"
          ".config/draw.io"
          ".config/drawio"
        ];
      };
      zotero = {
        package = pkgs.zotero;
        executable = "bin/zotero";
        capabilities = acceleratedDocumentCapabilities ++ [
          "network"
          "runtime-introspection"
          "shared-memory"
          "userns"
        ];
        homePaths = [
          ".cache/zotero"
          ".zotero"
        ];
      };
      logseq = {
        package = pkgs.logseq-appimage;
        executable = "bin/logseq-appimage";
        capabilities = electronDocumentCapabilities;
        extraExecutables = [ "/nix/store/*-${pkgs.logseq-appimage.name}-bwrap" ];
        homePaths = [
          ".config/Logseq"
          ".pki/nssdb"
          "logseq"
        ];
      };
      textmaker = {
        package = softmakerOffice;
        executable = "bin/softmaker-office-nx-textmaker";
        capabilities = acceleratedDocumentCapabilities ++ [ "network" ];
        homePaths = [ "SoftMaker" ];
      };
      planmaker = {
        package = softmakerOffice;
        executable = "bin/softmaker-office-nx-planmaker";
        capabilities = acceleratedDocumentCapabilities ++ [ "network" ];
        homePaths = [ "SoftMaker" ];
      };
      presentations = {
        package = softmakerOffice;
        executable = "bin/softmaker-office-nx-presentations";
        capabilities = acceleratedDocumentCapabilities ++ [ "network" ];
        homePaths = [ "SoftMaker" ];
      };
      brave = {
        package = pkgs.brave;
        capabilities = browserCapabilities;
        homePaths = [
          ".cache/BraveSoftware"
          ".config/BraveSoftware"
        ];
        sensitiveAccess = [ "credential-broker" ];
      };
      glide = {
        package = pkgs.flake.glide-browser;
        executable = "bin/glide";
        capabilities = browserCapabilities;
        homePaths = [
          ".cache/glide"
          ".config/glide"
        ];
        sensitiveAccess = [ "credential-broker" ];
      };
      mullvad-browser = {
        package = pkgs.mullvad-browser;
        executable = "bin/mullvad-browser";
        capabilities = browserCapabilities;
        homePaths = [
          ".cache/mullvad"
          ".mullvad"
        ];
        sensitiveAccess = [ "credential-broker" ];
      };
      vivaldi = {
        package = pkgs.vivaldi;
        capabilities = browserCapabilities;
        homePaths = [
          ".cache/vivaldi"
          ".config/vivaldi"
        ];
        sensitiveAccess = [ "credential-broker" ];
      };
      thunderbird = {
        package = pkgs.thunderbird;
        capabilities = acceleratedDocumentCapabilities ++ [
          "audio"
          "network"
          "runtime-introspection"
          "shared-memory"
          "userns"
        ];
        homePaths = [
          ".cache/thunderbird"
          ".thunderbird"
        ];
      };
      protonmail-bridge = {
        package = pkgs.protonmail-bridge;
        executable = "bin/protonmail-bridge";
        capabilities = acceleratedDesktopCapabilities ++ [
          "credential-broker"
          "network"
        ];
        homePaths = [
          ".cache/protonmail"
          ".config/protonmail"
        ];
        sensitiveAccess = [ "credential-broker" ];
      };
      proton-pass = {
        package = pkgs.proton-pass;
        executable = "bin/proton-pass";
        capabilities = electronCapabilities ++ [ "credential-broker" ];
        executionPackages = [ pkgs.electron ];
        homePaths = [
          ".cache/Proton Pass"
          ".config/Proton Pass"
        ];
        sensitiveAccess = [ "credential-broker" ];
      };
      proton-pass-cli = {
        package = pkgs.proton-pass-cli;
        executable = "bin/pass-cli";
        capabilities = [
          "credential-broker"
          "network"
          "terminal"
        ];
        homePaths = [ ".config/proton-pass-cli" ];
        sensitiveAccess = [ "credential-broker" ];
      };
      proton-vpn = {
        package = pkgs.proton-vpn;
        executable = "bin/protonvpn-app";
        capabilities = acceleratedDesktopCapabilities ++ [
          "network"
          "system-bus"
        ];
        homePaths = [
          ".cache/Proton/VPN"
          ".config/Proton/VPN"
        ];
      };
      qbittorrent = {
        package = pkgs.qbittorrent;
        capabilities = acceleratedDocumentCapabilities ++ [ "network" ];
        homePaths = [
          ".cache/qBittorrent"
          ".config/qBittorrent"
          ".local/share/qBittorrent"
        ];
      };
      motrix = {
        package = pkgs.motrix-next;
        executable = "bin/motrix-next";
        capabilities = electronDocumentCapabilities;
        extraClosureRoots = [ pkgs.glibc.bin ];
        extraExecutables = [ "${pkgs.glibc.bin}/bin/getconf" ];
        homePaths = [
          ".cache/Motrix"
          ".config/Motrix"
          ".config/motrix"
        ];
      };
      deezer = {
        package = pkgs.deezer-enhanced;
        executable = "bin/deezer-enhanced";
        capabilities = electronCapabilities ++ [ "audio" ];
        homePaths = [ ".config/deezer-enhanced" ];
      };
      codex-cli = {
        package = pkgs.flake.codex-cli;
        executable = "bin/codex";
        capabilities = [
          "developer-exec"
          "full-home"
          "network"
          "terminal"
          "userns"
        ];
        namespaceExecutables = [ "${pkgs.flake.codex-cli}/bin/.codex-wrapped" ];
        namespaceRules = ''
          capability setpcap,
          capability sys_admin,
          capability sys_ptrace,
        '';
        sensitiveAccess = [
          "gpg-agent"
          "ssh-config"
          "ssh-control"
          "ssh-identities"
        ];
      };
      claude-code = {
        package = pkgs.flake.claude-code;
        executable = "bin/claude";
        capabilities = [
          "developer-exec"
          "full-home"
          "network"
          "terminal"
        ];
        sensitiveAccess = [
          "gpg-agent"
          "ssh-config"
          "ssh-control"
          "ssh-identities"
        ];
      };
    }
    // lib.optionalAttrs (codexDesktopPackage != null) {
      codex-desktop = {
        package = codexDesktopPackage;
        executable = "bin/codex-desktop";
        capabilities = electronCapabilities ++ [
          "audio"
          "developer-exec"
          "full-home"
          "terminal"
        ];
        homePaths = [
          ".codex"
          ".config/Codex"
        ];
        sensitiveAccess = [
          "gpg-agent"
          "ssh-config"
          "ssh-control"
          "ssh-identities"
        ];
      };
    };

    developerPackages = with pkgs; [
      bash
      coreutils
      coreutils-full
      findutils
      gnugrep
      gnused
      gawk
      git
      jujutsu
      nix
      openssh_hpn
      ripgrep
      fd
      gcc
      gnumake
      cmake
      python3
      nodejs
      uv
      gh
      stable.helix
      neovim
      ast-grep
      entr
      file
      fzf
      nixfmt
      rustfmt
      shfmt
      zig
      typst
      typstyle
      tinymist
      typst-live
      ltex-ls-plus
      marksman
      nixd
      ruff
      ty
      glab
      hub
      fluxcd
      k9s
      kubernetes-helm
      kubectl
      opentofu
      terraform
      terraform-ls
    ];

    inventory = {
      easyeffects = {
        kind = "application";
        status = "candidate";
        target = "easyeffects";
        rationale = "Audio graph and PipeWire integration need a dedicated complain-mode workload trace.";
      };
      guvcview = {
        kind = "application";
        status = "candidate";
        target = "guvcview";
        rationale = "Camera, USB, audio, and codec access need a dedicated device profile.";
      };
      junction = {
        kind = "application";
        status = "candidate";
        target = "junction";
        rationale = "URL dispatch and portal interactions require a representative workload trace.";
      };
      pavucontrol = {
        kind = "application";
        status = "candidate";
        target = "pavucontrol";
        rationale = "PipeWire and PulseAudio control interfaces need a dedicated capability review.";
      };
      via = {
        kind = "application";
        status = "candidate";
        target = "via";
        rationale = "Raw HID and Electron permissions need a hardware-backed workload trace.";
      };
      yubioath = {
        kind = "application";
        status = "candidate";
        target = "yubioath-flutter";
        rationale = "Smart-card, USB, and credential access need a dedicated threat model.";
      };
      broad-launchers = {
        kind = "application";
        status = "exempt";
        target = "shells, terminals, Nautilus, editors, and agent launchers";
        rationale = "They intentionally launch arbitrary user-selected commands and require a separate launcher model.";
      };
      privileged-admin = {
        kind = "application";
        status = "exempt";
        target = "GParted and hardware/virtualization administration tools";
        rationale = "Privilege transitions and device ownership require dedicated profiles and enforced VM tests.";
      };
    };
  };

  systemd.user.services.codex-remote-control.Install.WantedBy = lib.mkForce [ ];
}

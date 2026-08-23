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
    "shared-memory"
    "userns"
  ];
  electronDocumentCapabilities = electronCapabilities ++ [ "user-files" ];
  browserCapabilities = electronCapabilities ++ [
    "audio"
    "camera"
    "credential-broker"
    "device-discovery"
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
  electronExecutionPackages = [
    pkgs.electron
    pkgs.electron.unwrapped
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
      dnsutils # DNS lookup utilities (dig, host, nslookup)
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
        extraRules = ''
          owner @{HOME}/.local/share/gvfs-metadata/{,**} r,
        '';
        extraRulesRationale = "Evince reads GVFS metadata associated with opened documents.";
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
          ".config/enchant"
          ".config/inkscape"
        ];
      };
      drawio = {
        package = pkgs.drawio;
        capabilities = electronDocumentCapabilities;
        executionPackages = electronExecutionPackages;
        profileReentryExecutables = [ "${pkgs.electron}/bin/electron" ];
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
        extraExecutables = [
          "${pkgs.logseq-appimage.appimageContents}/AppRun"
          "${pkgs.logseq-appimage.appimageContents}/chrome-sandbox"
          "${pkgs.logseq-appimage.appimageContents}/chrome_crashpad_handler"
          "${pkgs.logseq-appimage.appimageContents}/logseq"
        ];
        extraRules = ''
          ${pkgs.logseq-appimage.appimageContents}/*.so* mr,
        '';
        extraRulesRationale = "Logseq maps Electron libraries from the root of its extracted AppImage.";
        homePaths = [
          ".logseq"
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
        extraRules = ''
          owner @{HOME}/.config/BraveSoftware/Brave-Browser/WidevineCdm/*/_platform_specific/linux_x64/libwidevinecdm.so mr,
          /dev/hidraw[0-9]* rw,
          /run/udev/data/+hid:0003:1050:0407.* r,
          /sys/devices/**/0003:1050:0407.*/report_descriptor r,
        '';
        extraRulesRationale = "Brave maps its downloaded Widevine CDM and directly accesses raw-HID FIDO authenticators such as YubiKeys.";
        homePaths = [
          ".cache/BraveSoftware"
          ".config/BraveSoftware"
          ".pki/nssdb"
        ];
        sensitiveAccess = [ "credential-broker" ];
        elevatedAccessRationale = "Brave uses the desktop secret-service broker for user-approved credentials.";
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
        elevatedAccessRationale = "Glide uses the desktop secret-service broker for user-approved credentials.";
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
        elevatedAccessRationale = "Mullvad Browser uses the desktop secret-service broker for user-approved credentials.";
      };
      vivaldi = {
        package = pkgs.vivaldi;
        capabilities = browserCapabilities;
        homePaths = [
          ".cache/vivaldi"
          ".config/vivaldi"
        ];
        sensitiveAccess = [ "credential-broker" ];
        elevatedAccessRationale = "Vivaldi uses the desktop secret-service broker for user-approved credentials.";
      };
      thunderbird = {
        package = pkgs.thunderbird;
        capabilities = acceleratedDocumentCapabilities ++ [
          "audio"
          "network"
          "shared-memory"
          "userns"
        ];
        extraExecutables = [
          "${pkgs.thunderbird.unwrapped}/lib/thunderbird/glxtest"
          "${pkgs.thunderbird.unwrapped}/lib/thunderbird/pingsender"
          "${pkgs.thunderbird.unwrapped}/lib/thunderbird/vaapitest"
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
          ".local/share/protonmail"
        ];
        sensitiveAccess = [ "credential-broker" ];
        elevatedAccessRationale = "Proton Mail Bridge stores its authentication material through the secret-service broker.";
      };
      proton-pass = {
        package = pkgs.proton-pass;
        executable = "bin/proton-pass";
        capabilities = electronCapabilities ++ [ "credential-broker" ];
        executionPackages = electronExecutionPackages;
        homePaths = [
          ".cache/Proton Pass"
          ".config/Proton Pass"
        ];
        sensitiveAccess = [ "credential-broker" ];
        elevatedAccessRationale = "Proton Pass stores its authentication material through the secret-service broker.";
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
        elevatedAccessRationale = "Proton Pass CLI stores its authentication material through the secret-service broker.";
      };
      proton-vpn = {
        package = pkgs.proton-vpn;
        executable = "bin/protonvpn-app";
        capabilities = acceleratedDesktopCapabilities ++ [
          "network"
        ];
        systemBusPeers = [
          "org.freedesktop.NetworkManager"
          "org.freedesktop.login1"
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
        extraRules = ''
          deny ptrace read peer=unconfined,
        '';
        extraRulesRationale = "qBittorrent's optional host-process inspection is intentionally unavailable.";
      };
      motrix = {
        package = pkgs.motrix-next;
        executable = "bin/motrix-next";
        capabilities = electronDocumentCapabilities;
        executionPackages = [ pkgs.webkitgtk_4_1 ];
        homePaths = [
          ".cache/Motrix"
          ".config/Motrix"
          ".config/motrix"
          ".local/share/com.motrix.next"
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
          "bubblewrap"
          "containers"
          "developer-exec"
          "host-diagnostics"
          "network"
          "terminal"
          "user-files"
        ];
        bubblewrapPackage = pkgs.stable.bubblewrap;
        containerToolsPackage = pkgs.flake.agent-container-tools;
        homePaths = [ ".codex" ];
        extraRules = ''
          owner @{HOME}/.cache/codex-runtimes/{,**} rwkl,
          owner @{HOME}/.gnupg/.#lk* rwk,
        '';
        extraRulesRationale = "Codex updates its managed runtime cache and GnuPG creates a transient lock beside the explicitly allowed agent state.";
        sensitiveAccess = [
          "gpg-agent"
          "nixos-config-writable"
          "netrc"
          "ssh-config"
          "ssh-control"
          "ssh-identities"
        ];
        elevatedAccessRationale = "Codex needs developer execution, its state, reviewed source trees, and the configured SSH/GPG brokers.";
      };
      claude-code = {
        package = pkgs.flake.claude-code;
        executable = "bin/claude";
        capabilities = [
          "bubblewrap"
          "containers"
          "developer-exec"
          "host-diagnostics"
          "network"
          "terminal"
          "user-files"
        ];
        bubblewrapPackage = pkgs.stable.bubblewrap;
        containerToolsPackage = pkgs.flake.agent-container-tools;
        homePaths = [ ".claude" ];
        extraRules = ''
          owner @{run}/user/[0-9]*/cc-socks/{,**} rwkl,
          /etc/claude-code/managed-settings.d/{,**} r,
          owner @{HOME}/.claude.json rwkl,
          owner @{HOME}/.claude.json.tmp.* rwkl,
          owner @{HOME}/.claude.json.lock/{,**} rwkl,
          owner @{HOME}/.cache/claude-cli-nodejs/{,**} rwkl,
          owner @{HOME}/.local/share/mime/{globs,magic} r,
          owner @{HOME}/.local/share/applications/claude-code-url-handler.desktop r,
        '';
        extraRulesRationale = "Claude Code reads its managed policy and desktop integration while atomically updating its CLI state, runtime cache, and local proxy sockets.";
        sensitiveAccess = [
          "gpg-agent"
          "nixos-config-writable"
          "ssh-config"
          "ssh-control"
          "ssh-identities"
        ];
        elevatedAccessRationale = "Claude Code needs developer execution, its state, reviewed source trees, and the configured SSH/GPG brokers.";
      };
    }
    // lib.optionalAttrs (codexDesktopPackage != null) {
      codex-desktop = {
        package = codexDesktopPackage;
        executable = "bin/codex-desktop";
        capabilities = electronCapabilities ++ [
          "audio"
          "developer-exec"
          "host-diagnostics"
          "terminal"
          "user-files"
        ];
        homePaths = [
          ".codex"
          ".config/Codex"
          ".config/codex-desktop"
        ];
        sensitiveAccess = [
          "gpg-agent"
          "nixos-config-writable"
          "ssh-config"
          "ssh-control"
          "ssh-identities"
        ];
        elevatedAccessRationale = "Codex Desktop needs developer execution, its state, reviewed source trees, and the configured SSH/GPG brokers.";
      };
    };

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

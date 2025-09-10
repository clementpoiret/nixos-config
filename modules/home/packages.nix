{ pkgs, ... }:
{
  home.packages = (
    with pkgs;
    [
      # General Utilities
      # bitwise # CLI tool for bit/hex manipulation
      # bleachbit # Disk space cleaner and privacy tool
      ast-grep
      bluetuith # Bluetooth device management
      cliphist # Wayland clipboard history manager
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
      lazysql # Like lazygit, but for sql
      lsd # Modern ls with colors/icons
      lz4 # Extremely fast lossless compression
      man-pages # Additional manual pages
      ncdu # Disk usage analyzer with ncurses interface
      nitch # System information fetch utility
      pamixer # PulseAudio CLI mixer
      pavucontrol # PulseAudio volume control GUI
      playerctl # Media player controller
      pqiv # Powerful X11 image viewer
      # pueue # Background task manager for long-running jobs
      qalculate-gtk # Advanced calculator (GTK interface)
      ripgrep # grep replacement
      serpl # SerpAPI CLI for search engine results
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
      protonmail-bridge
      protonmail-bridge-gui
      protonvpn-cli # ProtonVPN command-line interface
      protonvpn-gui # ProtonVPN graphical interface
      rclone # Cloud storage synchronization
      wget # Non-interactive network downloader

      # Development Tools
      cmake # Cross-platform build system
      devenv # Reproducible development environments with Nix
      gcc # GNU Compiler Collection
      gnumake # GNU make build automation
      nixfmt-rfc-style # nix formatter
      rustfmt # Rust code formatter
      shfmt # Shell script formatter
      zig # General-purpose programming language/toolchain

      # Scientific writing
      # typst
      typst
      typstyle
      tinymist
      typst-live

      # Language Servers
      basedpyright # Python language server (Pyright-based)
      ltex-ls-plus
      marksman
      nixd # Nix language server
      ruff # Python LSP
      rust-analyzer # Rust language server
      ty
      vscode-extensions.vadimcn.vscode-lldb # VS Code LLDB debugger extension
      zls # Zig language server

      # Package Management
      nix-prefetch-github # Prefetch GitHub repository hashes for Nix
      uv # Python package installer/resolver (Astral)

      # Version Control
      gh # GitHub CLI
      # gh-dash # GitHub CLI dashboard
      glab # GitLab CLI
      hub # GitHub-focused wrapper for git

      # Containers & Orchestration
      docker # Container runtime
      fluxcd # Continuous delivery for Kubernetes
      k9s # Kubernetes CLI interface
      kubernetes-helm # Kubernetes package manager
      kubectl # Kubernetes command-line client

      # Infrastructure as Code
      opentofu # Open-source Terraform-compatible IaC
      terraform # Infrastructure as Code tool (HashiCorp)
      terraform-ls # Terraform language server

      # Browsers
      # brave # Privacy-focused web browser
      firefox-devedition # Firefox Developer Edition
      flake.zen-browser # Privacy-focused browser (Zen)
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
      libreoffice-fresh # Office suite
      onlyoffice-desktopeditors # Office suite
      pdftk # PDF document manipulation toolkit
      poppler # PDF rendering library (CLI tools)
      tdf # Terminal PDF reader
      zotero-beta # Reference management

      # Security
      age # Simple modern file encryption
      openssl # SSL/TLS protocol implementation
      proton-pass # Password manager
      sops # Encrypted secrets management

      # Communication
      signal-desktop-bin # Signal messaging client
      # zoom-us # Video conferencing client

      # Miscellaneous
      bibiman # Bibliography management CLI
      # en-croissant # Chess Tool
      gemini-cli # Gemini protocol client
      # libation # Extract audio books
      libnotify # Desktop notification library
      poweralertd # Power alert daemon (low battery/etc.)
      qmk
      wiper # Secure file deletion tool
      wl-screenrec
      xdg-utils # Desktop integration scripts (open/mailto)
    ]
  );
}

{ pkgs, ... }:
{
  home.packages = (
    with pkgs;
    [
      # aerc # for emails
      age # for my secrets
      awscli2
      bruno # for REST APIs tests
      bitwise # cli tool for bit / hex manipulation
      dconf-editor
      dmidecode
      drawio
      entr # perform action when file change
      exfat
      fd # find replacement
      file # Show file information
      fzf # fuzzy finder
      gh # github cli
      gh-dash
      glab
      gifsicle # gif utility
      gnuplot
      gtt # google translate TUI
      gtrash # rm replacement, put deleted files in system trash
      graphviz
      hexdump
      hub # wrapper around git
      inkscape
      inxi # system info
      killall # to kill our little friends
      lsd # ls replacement
      lshw
      lz4
      # magic-wormhole # magic file transfer
      nitch # systhem fetch util
      nix-prefetch-github
      pciutils
      ripgrep # grep replacement
      sops
      spotify-player
      toipe # typing test in the terminal
      tldr # user-friendly help
      wormhole-william # magic wormhole in Go
      yarn
      zenity

      # Markdown
      ltex-ls-plus
      marksman
      # WARNING: This is broken, it only installs the first plugin in the list...
      # I'll use uvx instead.
      # (mdformat.withPlugins (p: [
      #   p.mdformat-gfm
      #   p.mdformat-frontmatter
      #   p.mdformat-footnote
      # ]))

      # lldb
      vscode-extensions.vadimcn.vscode-lldb

      # C / C++
      cmake
      gcc
      gnumake

      # Rust
      cargo
      rust-analyzer
      rustfmt

      # bash
      shfmt

      # Nix
      nixd
      nixfmt-rfc-style

      # Python
      (import ./python-packages.nix { pkgs = pkgs; })
      micromamba
      ruff
      uv
      basedpyright
      pylyzer
      ruff

      # Zig
      zig
      zls

      # infra
      docker
      fluxcd
      k9s
      kubernetes-helm
      kubectl
      lens
      minikube
      opentofu
      terraform
      terraform-ls

      # aider-chat
      aria2
      bibiman
      bleachbit # cache cleaner
      bluetuith
      chromium
      devenv # reproducible dev env based on nix
      drawio
      dust
      evince # gnome pdf viewer
      ffmpeg
      file-roller
      firefox-devedition-bin
      gparted # partition manager
      hugo
      #lens
      libnotify
      man-pages # extra man pages
      mpv # video player
      ncdu # disk space
      onlyoffice-desktopeditors
      openssl
      pamixer # pulseaudio command line mixer
      pavucontrol # pulseaudio volume controle (GUI)
      poppler # pdf preview
      pdftk
      playerctl # controller for media players
      pqiv
      proton-pass
      protonvpn-gui
      protonvpn-cli
      poweralertd
      pueue # manage long running tasks
      qalculate-gtk # calculator
      qFlipper
      qmk
      rclone
      serpl
      signal-desktop-bin
      tdf # read pdfs in terminal
      unzip
      via # keyboard config
      wget
      wl-clipboard
      stable.wush # transfer between computers, stable to have v0.3.0
      cliphist
      wiper
      xdg-utils
      xxd
      zotero-beta

      flake.alejandra
      flake.zen-browser
    ]
  );
}

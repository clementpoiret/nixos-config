{ pkgs, ... }:
{
  home.packages = (
    with pkgs;
    [
      # aerc # for emails
      age # for my secrets
      awscli2
      # bruno # for REST APIs tests
      bitwise # cli tool for bit / hex manipulation
      dconf-editor
      dmidecode
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
      # spotify-player
      toipe # typing test in the terminal
      tldr # user-friendly help
      wormhole-william # magic wormhole in Go
      # yarn
      # youtube-music
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

      # typst
      typst
      typstyle
      tinymist
      typst-live

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
      basedpyright
      micromamba
      ruff
      master.ty
      uv
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
      # lens
      # minikube
      opentofu
      terraform
      terraform-ls

      # aider-chat
      aria2
      bibiman
      brave
      bleachbit # cache cleaner
      bluetuith
      # chromium
      # google-chrome
      # firefox-beta-bin
      devenv # reproducible dev env based on nix
      drawio
      dust
      evince # gnome pdf viewer
      ffmpeg
      file-roller
      firefox-devedition
      gparted # partition manager
      hugo
      hunspell
      hunspellDicts.fr-any
      #lens
      libation
      libnotify
      libreoffice-fresh
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
      stable.qmk
      rclone
      serpl
      signal-desktop-bin
      tdf # read pdfs in terminal
      unzip
      via # keyboard config
      wget
      wl-clipboard
      wush # transfer between computers, stable to have v0.3.0
      cliphist
      wiper
      xdg-utils
      xxd
      zotero-beta
      zoom-us

      flake.alejandra
      flake.zen-browser
    ]
  );
}

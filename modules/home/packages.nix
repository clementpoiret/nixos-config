{ pkgs, ... }:
{
  home.packages = (
    with pkgs;
    [
      aerc # for emails
      age # for my secrets
      stable.awscli2
      beeper
      stable.bruno # for REST APIs tests
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
      glab
      gifsicle # gif utility
      gnuplot
      gtt # google translate TUI
      gtrash # rm replacement, put deleted files in system trash
      graphviz
      hexdump
      inkscape
      inxi # system info
      killall # to kill our little friends
      lazygit
      lsd # ls replacement
      lshw
      lz4
      # magic-wormhole # magic file transfer
      nitch # systhem fetch util
      nix-prefetch-github
      pciutils
      ripgrep # grep replacement
      russ
      sops
      spotify-player
      toipe # typing test in the terminal
      tldr # user-friendly help
      wormhole-william # magic wormhole in Go
      yarn
      zenity

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
      pipenv
      pixi
      poetry
      python312Packages.pytest
      python312Packages.pyflakes
      ruff
      master.uv

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
      obsidian
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
      tdf # read pdfs in terminal
      unzip
      via # keyboard config
      wget
      wl-clipboard
      master.wush # transfer between computers
      master.cliphist
      xdg-utils
      xxd
      zotero-beta

      flake.alejandra
      flake.zen-browser
    ]
  );
}

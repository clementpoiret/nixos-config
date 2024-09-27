{ inputs, pkgs, ... }: {
  home.packages = (with pkgs; [
    aerc # for emails
    age # for my secrets
    awscli2
    beeper
    bruno # for REST APIs tests
    bitwise # cli tool for bit / hex manipulation
    dmidecode
    drawio
    entr # perform action when file change
    exfat
    fd # find replacement
    file # Show file information
    fzf # fuzzy finder
    gh # github cli
    gifsicle # gif utility
    gtt # google translate TUI
    gtrash # rm replacement, put deleted files in system trash
    graphviz
    hexdump
    inkscape
    inxi # system info
    jdk
    killall # to kill our little friends
    lazygit
    libreoffice
    lsd # ls replacement
    lshw
    lxqt.lxqt-policykit
    lz4
    python311Packages.magic-wormhole # magic file transfer
    nautilus # file manager
    nitch # systhem fetch util
    nix-prefetch-github
    pciutils
    ripgrep # grep replacement
    russ
    sops
    spotify-player
    toipe # typing test in the terminal
    tldr # user-friendly help
    yarn
    zellij
    zenity

    # C / C++
    cmake
    gcc
    gnumake

    # Nix
    nil

    # Python
    (import ./python-packages.nix { pkgs = pkgs; })
    micromamba
    pipenv
    pixi
    poetry
    python311Packages.nose
    python311Packages.pytest
    python311Packages.pyflakes
    ruff
    master.uv

    # infra
    docker
    k9s
    kubernetes-helm
    kubectl
    minikube

    # aider-chat
    aria2
    bleachbit # cache cleaner
    chromium
    devenv # reproducible dev env based on nix
    direnv
    drawio
    dust
    evince # gnome pdf viewer
    ffmpeg
    file-roller
    firefox-devedition-bin
    gparted # partition manager
    libnotify
    man-pages # extra man pages
    mpv # video player
    ncdu # disk space
    obsidian
    openssl
    pamixer # pulseaudio command line mixer
    pavucontrol # pulseaudio volume controle (GUI)
    pdftk
    playerctl # controller for media players
    pqiv
    master.proton-pass
    protonvpn-gui
    protonvpn-cli
    poweralertd
    qalculate-gtk # calculator
    qFlipper
    rclone
    tdf # read pdfs in terminal
    unzip
    via # keyboard config
    wget
    wl-clipboard
    master.wush # transfer between computers
    cliphist
    xdg-utils
    xxd
    zotero-beta

    flake.alejandra
    flake.zen-browser
  ]);
}

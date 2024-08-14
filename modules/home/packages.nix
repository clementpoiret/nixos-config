{ inputs, pkgs, ... }: 
{
  home.packages = (with pkgs; [
    aerc                              # for emails
    age                               # for my secrets
    awscli2
    beeper
    bruno                             # for REST APIs tests
    bitwise                           # cli tool for bit / hex manipulation
    dmidecode
    drawio
    entr                              # perform action when file change
    exfat
    fd                                # find replacement
    file                              # Show file information 
    fzf                               # fuzzy finder
    gh                                # github cli
    gtt                               # google translate TUI
    gifsicle                          # gif utility
    gtrash                            # rm replacement, put deleted files in system trash
    hexdump
    inkscape
    inxi                              # system info
    jdk
    killall                           # to kill our little friends
    lazygit
    libreoffice
    lsd                               # ls replacement
    lshw
    lxqt.lxqt-policykit
    lz4
    python311Packages.magic-wormhole  # magic file transfer
    nautilus                          # file manager
    nitch                             # systhem fetch util
    nix-prefetch-github
    pciutils
    ripgrep                           # grep replacement
    russ
    spotify-player
    toipe                             # typing test in the terminal
    tldr                              # user-friendly help
    yarn
    zellij
    zenity

    # C / C++
    cmake
    gcc
    gnumake

    # Python
    (import ./python-packages.nix { pkgs = pkgs; })
    micromamba
    pipenv
    pixi
    poetry
    python311Packages.nose
    python311Packages.pytest
    python311Packages.pyflakes

    aria2
    bleachbit                         # cache cleaner
    chromium
    csvlens
    devenv                            # reproducible dev env based on nix
    direnv
    drawio
    dust
    evince                            # gnome pdf viewer
    gparted                           # partition manager
    ffmpeg
    firefox-devedition-bin
    libnotify
    man-pages                         # extra man pages
    mpv                               # video player
    ncdu                              # disk space
    obsidian
    openssl
    pamixer                           # pulseaudio command line mixer
    pavucontrol                       # pulseaudio volume controle (GUI)
    pdftk
    playerctl                         # controller for media players
    pqiv
    master.proton-pass
    protonvpn-gui
    protonvpn-cli
    poweralertd
    qalculate-gtk                     # calculator
    rclone
    tdf                               # read pdfs in terminal
    unzip
    wget
    wl-clipboard
    cliphist
    xdg-utils
    xxd
    zotero-beta

    inputs.alejandra.defaultPackage.${system}
  ]);
}

{ inputs, pkgs, ... }: 
{
  home.packages = (with pkgs; [
    aerc                              # for emails
    age                               # for my secrets
    awscli2
    beeper
    bruno                             # for REST APIs tests
    bitwise                           # cli tool for bit / hex manipulation
    cinnamon.nemo-with-extensions     # file manager
    dmidecode
    drawio
    entr                              # perform action when file change
    exfat
    fd                                # find replacement
    file                              # Show file information 
    fzf                               # fuzzy finder
    gh                                # github cli
    gtt                               # google translate TUI
    gnome.zenity
    gtrash                            # rm replacement, put deleted files in system trash
    hexdump
    inxi                              # system info
    killall                           # to kill our little friends
    lazygit
    libreoffice
    lsd                               # ls replacement
    lshw
    lxqt.lxqt-policykit
    magic-wormhole                    # magic file transfer
    nitch                             # systhem fetch util
    nix-prefetch-github
    obsidian
    pciutils
    ripgrep                           # grep replacement
    russ
    spotify-player
    toipe                             # typing test in the terminal
    tldr                              # user-friendly help
    yarn
    zellij

    # C / C++
    gcc
    gnumake

    # Python
    micromamba
    pixi
    (import ./python-packages.nix { pkgs = pkgs; })

    bleachbit                         # cache cleaner
    chromium
    drawio
    gparted                           # partition manager
    ffmpeg
    firefox-devedition-bin
    imv                               # image viewer
    libnotify
    man-pages                         # extra man pages
    mpv                               # video player
    ncdu                              # disk space
    openssl
    pamixer                           # pulseaudio command line mixer
    pavucontrol                       # pulseaudio volume controle (GUI)
    playerctl                         # controller for media players
    protonvpn-gui
    protonvpn-cli
    poweralertd
    qalculate-gtk                     # calculator
    unzip
    wget
    wl-clipboard
    cliphist
    xdg-utils
    xxd

    inputs.alejandra.defaultPackage.${system}
  ]);
}

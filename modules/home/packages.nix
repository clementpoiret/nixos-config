{ inputs, pkgs, ... }: 
{
  home.packages = (with pkgs; [
    aerc                              # for emails
    awscli2
    beeper
    bruno                             # for REST APIs tests
    bitwise                           # cli tool for bit / hex manipulation
    cinnamon.nemo-with-extensions     # file manager
    # copyq
    drawio
    entr                              # perform action when file change
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
    magic-wormhole                    # magic file transfer
    nitch                             # systhem fetch util
    nix-prefetch-github
    obsidian
    pciutils
    ripgrep                           # grep replacement
    spotify-player
    syncthing
    toipe                             # typing test in the terminal
    tldr                              # user-friendly help
    # wl-clipboard
    zellij

    # C / C++
    gcc
    gnumake

    # Python
    micromamba
    python3

    bleachbit                         # cache cleaner
    gparted                           # partition manager
    ffmpeg
    imv                               # image viewer
    libnotify
    man-pages                         # extra man pages
    mpv                               # video player
    ncdu                              # disk space
    openssl
    pamixer                           # pulseaudio command line mixer
    pavucontrol                       # pulseaudio volume controle (GUI)
    playerctl                         # controller for media players
    poweralertd
    qalculate-gtk                     # calculator
    unzip
    wget
    xdg-utils
    xxd
    inputs.alejandra.defaultPackage.${system}
  ]);
}

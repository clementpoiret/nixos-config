{ inputs, pkgs, ... }: 
{
  home.packages = (with pkgs; [
    bitwise                           # cli tool for bit / hex manipulation
    lsd                               # ls replacement
    entr                              # perform action when file change
    fd                                # find replacement
    file                              # Show file information 
    fzf                               # fuzzy finder
    gtt                               # google translate TUI
    killall                           # to kill our little friends
    gtrash                            # rm replacement, put deleted files in system trash
    hexdump
    lazygit
    libreoffice
    cinnamon.nemo-with-extensions     # file manager
    nitch                             # systhem fetch util
    nix-prefetch-github
    ripgrep                           # grep replacement
    toipe                             # typing test in the terminal
    gnome.zenity
    magic-wormhole                    # magic file transfer
    gh                                # github cli
    tldr                              # user-friendly help

    # C / C++
    gcc
    gnumake

    # Python
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

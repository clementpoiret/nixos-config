{ inputs, username, host, ... }: {
  imports = [
    ./bat.nix # better cat command
    ./btop.nix # resouces monitor
    ./easyeffect.nix # audio profile
    ./emacs/emacs.nix # emacs editor
    ./files/files.nix # custom files
    ./fuzzel.nix # launcher
    ./git.nix # version controle
    ./gtk.nix # gtk theme
    ./hyprland # window manager
    ./kitty.nix # terminal
    ./nushell/nushell.nix # shell
    ./spicetify.nix # spotify client
    ./swaync/swaync.nix # notification deamon
    ./micro.nix # nano replacement
    ./nvim/nvim.nix # neovim editor
    ./packages.nix # other packages
    ./qutebrowser/qutebrowser.nix # qutebrowser
    ./sops.nix # secrets mgmt
    ./swayosd.nix # volume and brightness feedbacks
    ./scripts/scripts.nix # personal scripts
    ./waybar # status bar
    ./xdg-mimes.nix # default apps
    ./yazi.nix # terminal file manager
    ./zsh/zsh.nix # shell
  ];
}

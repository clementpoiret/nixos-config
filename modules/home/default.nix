{
  ...
}:
{
  imports = [
    # ./aichat.nix
    ./bat.nix # better cat command
    ./btop.nix # resouces monitor
    ./chtsh.nix
    ./easyeffect.nix # audio profile
    ./fuzzel.nix # launcher
    ./ghostty.nix # the best terminal emulator
    ./git/git.nix # version controle
    # ./gitui/gitui.nix # lazygit replacement
    ./gtk.nix # gtk theme
    ./helix.nix
    ./hyprland # window manager
    ./jj.nix # just another version control tool
    ./kitty.nix # terminal
    ./lazygit.nix
    ./nushell/nushell.nix # shell
    # ./ptpython.nix # python repl
    # ./spicetify.nix # spotify client
    ./swaync/swaync.nix # notification deamon
    ./nemo.nix # file manager
    ./nvim/nvim.nix # neovim editor
    ./packages.nix # other packages
    ./sops.nix # secrets mgmt
    ./superfile.nix # file manager
    ./swayosd.nix # volume and brightness feedbacks
    ./scripts/scripts.nix # personal scripts
    ./taskwarrior.nix
    ./tmux.nix
    ./waybar # status bar
    ./wl-kbptr.nix
    ./xdg-mimes.nix # default apps
    ./yazi.nix # terminal file manager
    ./zellij/zellij.nix # terminal multiplexer
    ./zk/zk.nix # zettelkasten
    ./zsh/zsh.nix # shell
  ];
}

{ ... }:
{
  imports = [
    ./aerc.nix # mail
    ./bat.nix # better cat command
    ./btop.nix # resouces monitor
    ./chtsh.nix
    ./cleanup.nix # auto delete files
    ./easyeffect.nix # audio profile
    ./fuzzel.nix # launcher
    ./ghostty/ghostty.nix # the best terminal emulator
    ./git/git.nix # version controle
    ./gpg.nix # gpg
    ./gtk.nix # gtk theme
    ./helix.nix
    ./jj.nix # just another version control tool
    ./kitty.nix # terminal
    ./lazygit.nix
    ./niri.nix # wm
    ./nushell/nushell.nix # shell
    ./nvim/nvim.nix # neovim editor
    ./packages.nix # other packages
    ./quickshell/quickshell.nix # UI widgets
    ./sops.nix # secrets mgmt
    ./stylix.nix # ricing
    ./ssh.nix # ssh
    ./superfile.nix # file manager
    ./scripts/scripts.nix # personal scripts
    ./tmux.nix
    ./wl-kbptr.nix
    ./xdg-mimes.nix # default apps
    ./yazi.nix # terminal file manager
    ./zed.nix
    # ./zellij/zellij.nix # terminal multiplexer
    ./zk/zk.nix # zettelkasten
    ./zsh/zsh.nix # shell
  ];
}

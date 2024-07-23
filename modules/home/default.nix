{inputs, username, host, ...}: {
  imports =
       [(import ./bat.nix)]                       # better cat command
    ++ [(import ./btop.nix)]                      # resouces monitor 
    ++ [(import ./easyeffect.nix)]                # audio profile
    ++ [(import ./emacs/emacs.nix)]                 # emacs editor
    ++ [(import ./floorp/floorp.nix)]             # firefox based browser
    ++ [(import ./fuzzel.nix)]                    # launcher
    ++ [(import ./git.nix)]                       # version controle
    ++ [(import ./gtk.nix)]                       # gtk theme
    ++ [(import ./hyprland)]                      # window manager
    ++ [(import ./kitty.nix)]                     # terminal
    ++ [(import ./spicetify.nix)]                 # spotify client
    ++ [(import ./swaync/swaync.nix)]             # notification deamon
    ++ [(import ./micro.nix)]                     # nano replacement
    ++ [(import ./nvim/nvim.nix)]                 # neovim editor
    ++ [(import ./packages.nix)]                  # other packages
    ++ [(import ./qutebrowser/qutebrowser.nix)]   # qutebrowser
    ++ [(import ./scripts/scripts.nix)]           # personal scripts
    ++ [(import ./waybar)]                        # status bar
    ++ [(import ./yazi.nix)]                      # terminal file manager
    ++ [(import ./zsh/zsh.nix)];                  # shell
}

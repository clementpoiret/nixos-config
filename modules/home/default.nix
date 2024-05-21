{inputs, username, host, ...}: {
  imports =
       [(import ./bat.nix)]                       # better cat command
    ++ [(import ./btop.nix)]                      # resouces monitor 
    ++ [(import ./floorp/floorp.nix)]             # firefox based browser
    ++ [(import ./git.nix)]                       # vertion controle
    ++ [(import ./gtk.nix)]                       # gtk theme
    ++ [(import ./hyprland)]                      # window manager
    ++ [(import ./kitty.nix)]                     # terminal
    ++ [(import ./mako.nix)]                      # notification deamon
    ++ [(import ./micro.nix)]                     # nano replacement
    ++ [(import ./nvim/nvim.nix)]                 # neovim editor
    ++ [(import ./packages.nix)]                  # other packages
    ++ [(import ./qutebrowser/qutebrowser.nix)]   # qutebrowser
    ++ [(import ./scripts/scripts.nix)]           # personal scripts
    ++ [(import ./swaylock.nix)]                  # lock screen
    ++ [(import ./waybar)]                        # status bar
    ++ [(import ./wofi.nix)]                      # launcher
    ++ [(import ./zsh.nix)];                      # shell
}

{ pkgs, ... }:
{
  home.packages = with pkgs; [ flake.ghostty ];

  xdg.configFile."ghostty/config".text = ''
    theme = catppuccin-mocha 
    gtk-titlebar = false
    # window-decoration = false
  '';
}

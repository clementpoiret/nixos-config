{ pkgs, ... }:
{
  home.packages = with pkgs; [ flake.ghostty ];

  xdg.configFile."ghostty/config".text = ''
    theme = catppuccin-mocha 
    gtk-titlebar = false
    font-family = "FiraCode Nerd Font"
    font-size = 10
  '';
}

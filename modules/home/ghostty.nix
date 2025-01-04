{ pkgs, ... }:
{
  home.packages = with pkgs; [ master.ghostty ];

  xdg.configFile."ghostty/config".text = ''
    theme = catppuccin-mocha 
    gtk-titlebar = false
    # gtk-tabs-location = hidden  # this renders a black window
    window-decoration = false
    font-family = "TX02 Nerd Font Mono Ret"
    # font-family = "TX-02"
    font-size = 10
    copy-on-select = true
    confirm-close-surface = false
  '';
}

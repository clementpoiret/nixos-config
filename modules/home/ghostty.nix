{ ... }:
{
  programs.ghostty = {
    enable = true;

    settings = {
      theme = "catppuccin-mocha";
      gtk-titlebar = false;
      "window-decoration" = false;
      font-family = "TX02 Nerd Font Ret";
      font-size = 10;
      copy-on-select = true;
      confirm-close-surface = false;
      window-padding-color = "extend";

      # keybind = [
      #   "super+shift+j=write_screen_file:open"
      # ];
    };
  };
}

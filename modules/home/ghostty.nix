{ ... }:
{
  programs.ghostty = {
    enable = true;

    settings = {
      theme = "catppuccin-mocha";
      gtk-titlebar = false;
      gtk-single-instance = true;
      gtk-tabs-location = "hidden";
      quit-after-last-window-closed = false;
      quit-after-last-window-closed-delay = "30m";
      linux-cgroup = "single-instance";
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

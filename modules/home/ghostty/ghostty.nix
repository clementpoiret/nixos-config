{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs.master.ghostty;

    settings = {
      theme = "catppuccin-mocha.conf";

      gtk-titlebar = false;
      gtk-single-instance = true;
      window-show-tab-bar = "never";
      quit-after-last-window-closed = false;
      quit-after-last-window-closed-delay = "30m";
      linux-cgroup = "single-instance";
      "window-decoration" = false;
      font-family = "TX02 Nerd Font Ret";
      font-size = 10;
      copy-on-select = true;
      confirm-close-surface = false;
      window-padding-color = "extend";

      quick-terminal-screen = "mouse";

      custom-shader = "./shaders/cursor-smear.glsl";

      keybind = [
        # "super+shift+j=write_screen_file:open"
        "global:super+shift+enter=toggle_quick_terminal"
      ];
    };
  };

  xdg.configFile."ghostty/themes/catppuccin-mocha.conf".source = ./catppuccin-mocha.conf;
  xdg.configFile."ghostty/shaders/cursor-smear.glsl".source = ./cursor-smear.glsl;
}

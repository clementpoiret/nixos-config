{ ... }:
{
  programs.ghostty = {
    enable = true;

    settings = {
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
        "global:alt+enter=toggle_quick_terminal"
      ];
    };
  };

  xdg.configFile."ghostty/shaders/cursor-smear.glsl".source = ./cursor-smear.glsl;
}

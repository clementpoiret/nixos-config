{ inputs, ... }:
{
  programs.ghostty = {
    enable = true;

    settings = {
      # theme = "dark:Rose Pine,light:Rose Pine Dawn";
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

      custom-shader-animation = "always";
      custom-shader = "./shaders/cursor_tail.glsl";

      shell-integration-features = "ssh-terminfo,ssh-env,sudo";

      keybind = [
        "global:alt+enter=toggle_quick_terminal"
        "cmd+shift+w=close_surface"
      ];
    };
  };

  xdg.configFile."ghostty/shaders/" = {
    source = inputs.ghosttyshaders;
    recursive = true;
    force = true;
  };

  # xdg.configFile."ghostty/shaders/cursor-smear.glsl".source = ./cursor-smear.glsl;
}

{
  inputs,
  pkgs,
  host,
  ...
}:
{
  localAppArmor.sessionReadPackages = [ pkgs.ghostty-host ];

  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    package = pkgs.ghostty-host;

    settings = {
      # theme = "dark:Rose Pine,light:Rose Pine Dawn";
      gtk-titlebar = false;
      gtk-single-instance = true;
      window-show-tab-bar = "never";

      quit-after-last-window-closed = false;
      quit-after-last-window-closed-delay = "30m";
      linux-cgroup = "single-instance";

      "window-decoration" = false;
      window-padding-color = "extend";
      font-family = "TX02 Nerd Font Ret";
      font-size = 10;

      copy-on-select = true;

      confirm-close-surface = false;

      quick-terminal-size = "50%,80%";

      # Render on terminal updates on the laptop; animate only while focused elsewhere.
      custom-shader-animation = host != "laptop";
      custom-shader = "./shaders/cursor_warp.glsl";
      # custom-shader = "./shaders/cursor_tail.glsl";

      shell-integration-features = "ssh-terminfo,ssh-env,sudo";

      notify-on-command-finish = "unfocused";
      notify-on-command-finish-action = "no-bell,notify";
      notify-on-command-finish-after = "30s";

      keybind = [
        # Pressed by niri's Alt+T bind through the niri shortcuts portal.
        "global:alt+t=toggle_quick_terminal"
        "cmd+shift+w=close_surface"
      ];
    };
  };

  # Ghostty binds global shortcuts only when it starts or reloads its configuration,
  # and a restarted portal frontend has lost every session.
  xdg.configFile."systemd/user/xdg-desktop-portal.service.d/ghostty-global-shortcuts.conf".text = ''
    [Service]
    ExecStartPost=-${pkgs.systemd}/bin/systemctl --user --no-block reload app-com.mitchellh.ghostty.service
  '';

  xdg.configFile."ghostty/shaders/" = {
    source = inputs.ghosttyshaders;
    recursive = true;
    force = true;
  };

  # xdg.configFile."ghostty/shaders/cursor-smear.glsl".source = ./cursor-smear.glsl;
}

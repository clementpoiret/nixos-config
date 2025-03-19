{
  lib,
  host,
  pkgs,
  config,
  ...
}:
{
  home.packages = with pkgs; [
    hyprcursor
    hyprpicker
    hyprsunset

    glib
    grim
    grimblast
    slurp
    swaybg
    wayland
    wl-clip-persist
    wf-recorder
  ];
  systemd.user.targets.hyprland-session.Unit.Wants = [ "xdg-desktop-autostart.target" ];
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    xwayland = {
      enable = true;
    };
    systemd.enable = false;
  };

  xdg.configFile = {
    "uwsm/env".text = # sh
      ''
        export NIXOS_OZONE_WL=1
        export ELECTRON_OZONE_PLATFORM_HINT="auto"
      '';

    "uwsm/env-hyprland".text = # sh
      ''
        # For Firefox to run on Wayland
        export MOZ_ENABLE_WAYLAND=1
        export MOZ_WEBRENDER=1

        export XDG_CURRENT_DESKTOP=Hyprland
        export XDG_SESSION_DESKTOP=Hyprland
        export XDG_SESSION_TYPE="wayland"
        export SDL_VIDEODRIVER="wayland"
        export CLUTTER_BACKEND="wayland"
        export GDK_BACKEND="wayland,x11,*"
        export QT_AUTO_SCREEN_SCALE_FACTOR="1"
        export QT_SCALE_FACTOR_ROUNDING_POLICY="RoundPreferFloor"
        export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
        export QT_QPA_PLATFORM="wayland;xcb"

        export _JAVA_AWT_WM_NONEREPARENTING="1"
        export DISABLE_QT5_COMPAT="0"
        export ANKI_WAYLAND="1"
        export DIRENV_LOG_FORMAT=""
        # export WLR_DRM_NO_ATOMIC="1"
      '';
  };

  home.file = lib.mkIf (host == "laptop") {
    # iGPU
    ".config/hypr/card" = {
      source = config.lib.file.mkOutOfStoreSymlink "/dev/dri/by-path/pci-0000:c5:00.0-card";
    };

    # dGPU
    ".config/hypr/fallbackCard" = {
      source = config.lib.file.mkOutOfStoreSymlink "/dev/dri/by-path/pci-0000:03:00.0-card";
    };
  };

  home.sessionVariables = lib.mkIf (host == "laptop") {
    WLR_DRM_DEVICES = "$HOME/.config/hypr/card:$HOME/.config/hypr/fallbackCard";
  };
}

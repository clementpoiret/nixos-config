{ inputs, lib, host, pkgs, config, ...}: 
let
  home = config.home.homeDirectory;
in
{
  home.packages = with pkgs; [
    inputs.hypr-contrib.packages.${pkgs.system}.grimblast
    inputs.hyprcursor.packages.${pkgs.system}.hyprcursor
    inputs.hyprpicker.packages.${pkgs.system}.hyprpicker
    inputs.hyprsunset.packages.${pkgs.system}.hyprsunset

    glib
    grim
    slurp
    swaybg
    wayland
    wl-clip-persist
    wf-recorder
  ];
  systemd.user.targets.hyprland-session.Unit.Wants = [ "xdg-desktop-autostart.target" ];
  wayland.windowManager.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    xwayland = {
      enable = true;
    };
    systemd.enable = true;
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

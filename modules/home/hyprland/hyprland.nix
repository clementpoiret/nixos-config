{ inputs, lib, host, pkgs, config, ...}: 
let
  home = config.home.homeDirectory;
in
{
  home.packages = with pkgs; [
    # swww
    swaybg
    inputs.hypr-contrib.packages.${pkgs.system}.grimblast
    hyprpicker
    grim
    slurp
    wl-clip-persist
    wf-recorder
    glib
    wayland
    direnv
    hyprcursor
  ];
  systemd.user.targets.hyprland-session.Unit.Wants = [ "xdg-desktop-autostart.target" ];
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland = {
      enable = true;
      # hidpi = true;
    };
    #enableNvidiaPatches = true;
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

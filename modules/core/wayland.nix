{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
    withUWSM = true;
    xwayland.enable = true;
  };

  services.displayManager.defaultSession = "hyprland-uwsm";

  programs.uwsm.enable = true;
  # environment.variables.UWSM_USE_SESSION_SLICE = "true";

  xdg.portal = {
    enable = true;
    wlr.enable = false;
    xdgOpenUsePortal = false;
    extraPortals = [
      # pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };
}

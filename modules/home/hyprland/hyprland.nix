{
  host,
  pkgs,
  config,
  ...
}:
let
  drmCards = {
    "laptop" = "/dev/dri/amd-igpu:/dev/dri/amd-dgpu";
  };
in
{
  home.packages = with pkgs; [
    hyprcursor
    hyprpicker

    glib
    grim
    grimblast
    slurp
    wayland
    wl-clip-persist
    wf-recorder

    xdg-utils
  ];

  services.hyprpolkitagent.enable = true;
  services.gnome-keyring = {
    enable = true;
    components = [
      "secrets"
      "ssh"
    ];
  };

  # systemd.user.targets.hyprland-session.Unit.Wants = [ "xdg-desktop-autostart.target" ];
  wayland.windowManager.hyprland = {
    enable = false;
    package = null;
    portalPackage = null;
    # package = pkgs.hyprland;
    # portalPackage = pkgs.xdg-desktop-portal-hyprland;
    # xwayland.enable = true;
    systemd.enable = false;

    # plugins = [
    #   pkgs.hyprlandPlugins.hyprspace
    # ];
  };

}

{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  niriInstance = lib.getExe (
    pkgs.writeShellScriptBin "niri-instance" ''
      /run/current-system/sw/bin/niri --session
    ''
  );
in
{
  imports = [
    inputs.dms.nixosModules.greeter
  ];

  services.greetd.enable = true;
  programs.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/clementpoiret";
  };

  environment = {
    systemPackages = with pkgs; [
      pkgs.niri
      xdg-desktop-portal
      # xwayland-satellite.packages.${pkgs.system}.default
    ];
    variables = {
      XDG_SESSION_TYPE = "wayland";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";
      # export GDK_BACKEND="wayland,x11,*"

      # For Firefox to run on Wayland
      MOZ_ENABLE_WAYLAND = 1;
      MOZ_WEBRENDER = 1;

      # For Electron apps to run on Wayland
      NIXOS_OZONE_WL = 1;
      ELECTRON_OZONE_PLATFORM_HINT = "auto";

      # QT
      QT_QPA_PLATFORM = "wayland";
      QT_QPA_PLATFORMTHEME = "gtk3";
      QT_QPA_PLATFORMTHEME_QT6 = "gtk3";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

      # Misc
      _JAVA_AWT_WM_NONEREPARENTING = "1";
      PROTON_PASS_KEY_PROVIDER = "fs";
    };
  };

  programs = {
    uwsm = {
      enable = true;
      package = pkgs.uwsm;
      waylandCompositors = {
        niri = {
          prettyName = "Niri";
          comment = "Niri compositor managed by UWSM";
          binPath = niriInstance;
        };
      };
    };
  };

  xdg.portal = {
    enable = true;
    wlr.enable = false;
    xdgOpenUsePortal = false;
    configPackages = [ pkgs.niri ];

    config.common = {
      default = [
        "gtk"
        "gnome"
      ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    };

    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
  };
}

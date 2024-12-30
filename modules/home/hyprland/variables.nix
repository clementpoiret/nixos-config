{
  ...
}:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    #SSH_ASKPASS = "${pkgs.lxqt.lxqt-openssh-askpass}/bin/lxqt-openssh-askpass";

    NIXOS_OZONE_WL = "1";
    __GL_GSYNC_ALLOWED = "0";
    __GL_VRR_ALLOWED = "0";
    _JAVA_AWT_WM_NONEREPARENTING = "1";
    #SSH_AUTH_SOCK = "/run/user/1000/keyring/ssh";
    DISABLE_QT5_COMPAT = "0";
    GDK_BACKEND = "wayland,x11,*";
    ANKI_WAYLAND = "1";
    DIRENV_LOG_FORMAT = "";
    WLR_DRM_NO_ATOMIC = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR_ROUNDING_POLICY = "RoundPreferFloor";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    # QT_QPA_PLATFORMTHEME = "qt5ct";
    # QT_STYLE_OVERRIDE = "kvantum";
    MOZ_ENABLE_WAYLAND = "1";
    #WLR_BACKEND = "vulkan";
    #WLR_RENDERER = "vulkan";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    # GTK_THEME = "Catppuccin-Mocha-Compact-Lavender-Dark";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    # WLR_NO_HARDWARE_CURSORS = "0";
  };

  # home.sessionVariables.LIBVA_DRIVER_NAME = lib.mkIf (host == "desktop") "nvidia";
  # home.sessionVariables.GBM_BACKEND = lib.mkIf (host == "desktop") "nvidia-drm";
  # home.sessionVariables.__GLX_VENDOR_LIBRARY_NAME = lib.mkIf (host == "desktop") "nvidia";
  # home.sessionVariables.NVD_BACKEND = lib.mkIf (host == "desktop") "direct";

  # VDPAU_DRIVER = "nvidia";
  # __NV_PRIME_RENDER_OFFLOAD = "1";
  # __VK_LAYER_NV_optimus = "NVIDIA_only";
  # PROTON_ENABLE_NGX_UPDATER = "1";
  # WLR_USE_LIBINPUT = "1";
  # XWAYLAND_NO_GLAMOR = "1";
  # __GL_MaxFramesAllowed = "1";
  # WLR_RENDERER_ALLOW_SOFTWARE = "1";
}

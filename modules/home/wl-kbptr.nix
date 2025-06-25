{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wl-kbptr
    wlrctl
  ];

  # TODO: refine with upcoming qmk mod
  wayland.windowManager.hyprland.extraConfig = ''
    # Cursor submap (similar to the Mouse mode in Sway)
    submap=cursor

    # Jump cursor to a position
    bind=,a,exec,hyprctl dispatch submap reset && wl-kbptr && hyprctl dispatch submap cursor
    bind=,z,exec,hyprctl dispatch submap reset && wl-kbptr -o modes=floating,click -o mode_floating.source=detect && hyprctl dispatch submap cursor

    # Cursor movement
    binde=,r,exec,wlrctl pointer move 0 10
    binde=,t,exec,wlrctl pointer move 0 -10
    binde=,i,exec,wlrctl pointer move 10 0
    binde=,l,exec,wlrctl pointer move -10 0
    binde=SHIFT,r,exec,wlrctl pointer move 0 100
    binde=SHIFT,t,exec,wlrctl pointer move 0 -100
    binde=SHIFT,i,exec,wlrctl pointer move 100 0
    binde=SHIFT,l,exec,wlrctl pointer move -100 0

    # Left button
    bind=,s,sendshortcut,,mouse:272,
    # Middle button
    bind=,e,sendshortcut,,mouse:274,
    # Right button
    bind=,n,sendshortcut,,mouse:273,

    # Scroll up and down
    # bind=,o,sendshortcut,,mouse_up,
    # bind=,p,sendshortcut,,mouse_down,
    # binde=,e,exec,wlrctl pointer scroll 10 0
    # binde=,r,exec,wlrctl pointer scroll -10 0

    # Scroll left and right
    # binde=,t,exec,wlrctl pointer scroll 0 -10
    # binde=,g,exec,wlrctl pointer scroll 0 10

    # Exit cursor submap
    # If you do not use cursor timeout or cursor:hide_on_key_press, you can delete its respective cals
    bind=,escape,exec,hyprctl keyword cursor:inactive_timeout 3; hyprctl keyword cursor:hide_on_key_press true; hyprctl dispatch submap reset 

    submap = reset

    # Entrypoint
    # If you do not use cursor timeout or cursor:hide_on_key_press, you can delete its respective cals
    bind=$mainMod,g,exec,hyprctl keyword cursor:inactive_timeout 0; hyprctl keyword cursor:hide_on_key_press false; hyprctl dispatch submap cursor
  '';

  xdg.configFile."wl-kbptr/config".text = # toml
    ''
      # wl-kbptr can be configured with a configuration file.
      # The file location can be passed with the -C parameter.
      # Othewise the `$XDG_CONFIG_HOME/wl-kbptr/config` file will
      # be loaded if it exits. Below is the default configuration.

      # [general]
      # home_row_keys=asenflrtiu
      # modes=tile,bisect

      [mode_tile]
      label_color=#cdd6f4
      label_select_color=#f38ba8
      unselectable_bg_color=#1e1e2e40
      selectable_bg_color=#1e1e2eB3
      selectable_border_color=#b4befe
      label_font_family=sans-serif
      label_symbols=abcdefghijklmnopqrstuvwxyz

      [mode_floating]
      label_color=#cdd6f4
      label_select_color=#f38ba8
      unselectable_bg_color=#1e1e2e40
      selectable_bg_color=#1e1e2eB3
      selectable_border_color=#b4befe
      label_font_family=sans-serif
      label_symbols=abcdefghijklmnopqrstuvwxyz

      # [mode_bisect]
      # label_color=#cdd6f4
      # label_font_size=20
      # label_font_family=sans-serif
      # label_padding=12
      # pointer_size=20
      # pointer_color=#e22d
      # unselectable_bg_color=#2226
      # even_area_bg_color=#0304
      # even_area_border_color=#0408
      # odd_area_bg_color=#0034
      # odd_area_border_color=#0048
      # history_border_color=#3339

      # [mode_click]
      # button=left
    '';
}

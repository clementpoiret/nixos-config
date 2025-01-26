{ pkgs, ... }:
{
  home.packages = [ pkgs.wl-kbptr ];

  # TODO: refine with upcoming qmk mod
  wayland.windowManager.hyprland.extraConfig = ''
    # Cursor submap (similar to the Mouse mode in Sway)
    submap=cursor

    # Jump cursor to a position
    bind=,a,exec,hyprctl dispatch submap reset && wl-kbptr && hyprctl dispatch submap cursor

    # Cursor movement
    # binde=,j,exec,wlrctl pointer move 0 10
    # binde=,k,exec,wlrctl pointer move 0 -10
    # binde=,l,exec,wlrctl pointer move 10 0
    # binde=,h,exec,wlrctl pointer move -10 0

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

}

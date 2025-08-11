{
  lib,
  host,
  ...
}:
let
  monitors =
    if (host == "desktop") then
      [
        "HDMI-A-1, preferred, auto, 1"
        "DP-1, preferred, auto-right, 1, transform, 1"
        "DP-2, preferred, auto-left, 1"
      ]
    else
      [
        "eDP-2, highres, auto, 1.6, bitdepth, 10, cm, wide, vrr, 1"
        "DP-3, highres, auto-right, 1.6, transform, 0"
        "DP-4, highres, auto-left, 2, bitdepth, 10, cm, wide, vrr, 1"
        "DP-12, highres, auto-left, 2, bitdepth, 10, cm, wide, vrr, 1"
      ];
  theme = import ../theme.nix;
  colors = theme.mocha.colors;
in
{
  wayland.windowManager.hyprland = {
    settings = {
      xwayland.force_zero_scaling = true;

      # autostart
      # for the first install, run "systemctl --user enable --now <service>.service"
      # for hypridle, hyprsunset, and waybar
      exec-once = [
        "systemctl --user import-environment"
        "uwsm finalize"
        "nm-applet"
        "wl-clip-persist --clipboard both"
        "swaybg -m fill -i $(find ~/Pictures/wallpapers/ -maxdepth 1 -type f)"
        "poweralertd"
        "uwsm-app swaync"
        "wl-paste --watch cliphist store"
      ];

      input = {
        kb_layout = "fr(ergol)";
        # kb_options = if (host == "desktop") then null else "compose:ralt";
        numlock_by_default = true;
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          tap-to-click = true;
        };
      };

      cursor = lib.mkIf (host == "desktop") {
        # TODO: Disable when vertical monitor bug fixed
        no_hardware_cursors = true;
        #allow_dumb_copy = true;
      };

      render = lib.mkIf (host == "desktop") { explicit_sync = false; };

      monitor = [
        # General rule
        ", preferred, auto, 1"
      ]
      ++ monitors;

      general = {
        "$mainMod" = "SUPER";
        layout = "master";
        gaps_in = 8;
        gaps_out = 8;
        border_size = 3;
        "col.active_border" = "rgb(${colors.blue.texthex}) rgb(${colors.lavender.texthex}) 45deg";
        "col.inactive_border" = "0x00000000";
        no_border_on_floating = false;
        # border_part_of_window = false;
      };

      misc = {
        disable_autoreload = true;
        disable_hyprland_logo = true;
        always_follow_on_dnd = true;
        layers_hog_keyboard_focus = true;
        animate_manual_resizes = false;
        enable_swallow = true;
        swallow_regex = "^(ghostty)$";
        focus_on_activate = true;
        vfr = true;
        vrr = 1;
      };

      plugin = [
        {
          overview = {
            gapsIn = 5;
            gapsOut = 5;
            panelHeight = 100;
            showEmptyWorkspace = false;
            showNewWorkspace = false;
            workspaceActiveBorder = "0xee${colors.lavender.texthex}";
          };
        }
      ];

      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
        workspace_swipe_forever = true;
      };

      dwindle = {
        force_split = 0;
        special_scale_factor = 1.0;
        split_width_multiplier = 1.0;
        use_active_for_splits = true;
        pseudotile = "yes";
        preserve_split = "yes";
      };

      master = {
        new_status = "slave";
        special_scale_factor = 1;
      };

      decoration = {
        rounding = 8;
        active_opacity = 1.0;
        inactive_opacity = 0.8;

        blur = {
          enabled = true;
          size = 2;
          passes = 4;
          brightness = 1;
          contrast = 1.4;
          ignore_opacity = true;
          noise = 0;
          new_optimizations = true;
          xray = true;
        };

        shadow = {
          enabled = true;
          color = "rgba(00000055)";
          ignore_window = true;
          offset = "0 2";
          range = 15;
          render_power = 2;
        };
      };

      animations = {
        enabled = true;

        bezier = [
          "fluent_decel, 0, 0.2, 0.4, 1"
          "easeOutCirc, 0, 0.55, 0.45, 1"
          "easeOutCubic, 0.33, 1, 0.68, 1"
          "easeinoutsine, 0.37, 0, 0.63, 1"
          "fade_curve, 0, 0.55, 0.45, 1"
        ];

        animation = [
          # Windows
          "windowsIn, 0, 4, easeOutCubic, popin 20%" # window open
          "windowsOut, 0, 4, fluent_decel, popin 80%" # window close.
          "windowsMove, 1, 2, fluent_decel, slide" # everything in between, moving, dragging, resizing.

          # Fade
          "fadeIn, 1, 3, fade_curve" # fade in (open) -> layers and windows
          "fadeOut, 1, 3, fade_curve" # fade out (close) -> layers and windows
          "fadeSwitch, 0, 1, easeOutCirc" # fade on changing activewindow and its opacity
          "fadeShadow, 1, 10, easeOutCirc" # fade on changing activewindow for shadows
          "fadeDim, 1, 4, fluent_decel" # the easing of the dimming of inactive windows
          "border, 1, 2.7, easeOutCirc" # for animating the border's color switch speed
          "borderangle, 1, 30, fluent_decel, once" # for animating the border's gradient angle - styles: once (default), loop
          "workspaces, 1, 4, easeOutCubic, fade" # styles: slide, slidevert, fade, slidefade, slidefadevert
        ];
      };

      bind = [
        # show keybinds list
        "$mainMod, F1, exec, show-keybinds"

        # app and scrips bindings
        "$mainMod, Return, exec, uwsm-app -- ghostty -e tmux new-session -t 'main'"
        # "$mainMod, Return, exec, uwsm-app -- ghostty -e zellij a -c --index 0"
        "$mainMod SHIFT, Return, exec, uwsm-app -- ghostty -e tmux"
        "ALT, Return, exec, uwsm-app -- ghostty"
        "$mainMod, T, exec, [float; size 950 600] uwsm-app -- ghostty -e 'nu -e \"twsync; twl\"'"
        "$mainMod, D, exec, fuzzel"
        "$mainMod, Q, killactive,"
        "$mainMod, F, fullscreen, 1"
        "$mainMod SHIFT, F, fullscreen, 0"
        "$mainMod, B, exec, uwsm-app -- zen"
        "$mainMod, Space, exec, toggle_float"
        "$mainMod, Escape, exec, uwsm-app -- hyprlock"
        "$mainMod SHIFT, Escape, exec, shutdown-script"
        "$mainMod, E, exec, uwsm-app -- ghostty -e superfile"
        "$mainMod ALT, B, exec, toggle_waybar"
        "$mainMod, C, exec, uwsm-app -- hyprpicker -a"
        "$mainMod, W, exec, wallpaper-picker"
        "$mainMod, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"
        "$mainMod, N, exec, swaync-client -t"
        # "$mainMod, SEMICOLON, exec, uwsm-app -- ghostty -e zellij --layout nvim"

        # plugins
        "$mainMod, O, overview:toggle"

        # master layout bindings
        "$mainMod, M, layoutmsg, focusmaster"
        "$mainMod SHIFT, M, layoutmsg, swapwithmaster"
        "$mainMod ALT, M, layoutmsg, addmaster"
        "$mainMod ALT SHIFT, M, layoutmsg, removemaster"
        "$mainMod, TAB, layoutmsg, cyclenext"
        "$mainMod SHIFT, TAB, layoutmsg, cycleprev"

        # screenshot
        "$mainMod, Print, exec, uwsm-app -- grimblast --notify --freeze save area ~/Pictures/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png"
        "$mainMod, Insert, exec, uwsm-app -- grimblast --notify --freeze save area ~/Pictures/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png"
        "$mainMod SHIFT, S, exec, uwsm-app -- grimblast --notify --freeze save area ~/Pictures/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png"
        "$mainMod SHIFT, C, exec, uwsm-app -- grimblast --notify --freeze copy area"
        ",Print, exec, uwsm-app -- grimblast --notify --cursor --freeze copy area"
        "ALT, Insert, exec, uwsm-app -- grimblast --notify --cursor --freeze copy area"

        # switch focus
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        "$mainMod, bracketleft, movefocus, l"
        "$mainMod, bracketright, movefocus, r"
        "$mainMod, minus, movefocus, u"
        "$mainMod, plus, movefocus, d"

        # switch workspace
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # same as above, but switch to the workspace
        "$mainMod SHIFT, 1, movetoworkspacesilent, 1"
        "$mainMod SHIFT, 2, movetoworkspacesilent, 2"
        "$mainMod SHIFT, 3, movetoworkspacesilent, 3"
        "$mainMod SHIFT, 4, movetoworkspacesilent, 4"
        "$mainMod SHIFT, 5, movetoworkspacesilent, 5"
        "$mainMod SHIFT, 6, movetoworkspacesilent, 6"
        "$mainMod SHIFT, 7, movetoworkspacesilent, 7"
        "$mainMod SHIFT, 8, movetoworkspacesilent, 8"
        "$mainMod SHIFT, 9, movetoworkspacesilent, 9"
        "$mainMod SHIFT, 0, movetoworkspacesilent, 10"
        "$mainMod CTRL, c, movetoworkspace, empty"

        # window control
        "$mainMod SHIFT, left, movewindow, l"
        "$mainMod SHIFT, right, movewindow, r"
        "$mainMod SHIFT, up, movewindow, u"
        "$mainMod SHIFT, down, movewindow, d"
        "$mainMod SHIFT, bracketleft, movewindow, l"
        "$mainMod SHIFT, bracketright, movewindow, r"
        "$mainMod SHIFT, minus, movewindow, u"
        "$mainMod SHIFT, plus, movewindow, d"

        "$mainMod CTRL, left, resizeactive, -80 0"
        "$mainMod CTRL, right, resizeactive, 80 0"
        "$mainMod CTRL, up, resizeactive, 0 -80"
        "$mainMod CTRL, down, resizeactive, 0 80"
        "$mainMod CTRL, bracketleft, resizeactive, -80 0"
        "$mainMod CTRL, bracketright, resizeactive, 80 0"
        "$mainMod CTRL, minus, resizeactive, 0 -80"
        "$mainMod CTRL, plus, resizeactive, 0 80"

        "$mainMod ALT, left, moveactive,  -80 0"
        "$mainMod ALT, right, moveactive, 80 0"
        "$mainMod ALT, up, moveactive, 0 -80"
        "$mainMod ALT, down, moveactive, 0 80"
        "$mainMod ALT, h, moveactive,  -80 0"
        "$mainMod ALT, j, moveactive, 0 80"
        "$mainMod ALT, k, moveactive, 0 -80"
        "$mainMod ALT, l, moveactive, 80 0"

        # media and volume controls
        #",XF86AudioRaiseVolume, exec, pamixer -i 2"
        #",XF86AudioLowerVolume, exec, pamixer -d 2"
        #",XF86AudioMute, exec, pamixer -t"
        ",XF86AudioPlay, exec, playerctl play-pause"
        ",XF86AudioNext, exec, playerctl next"
        ",XF86AudioPrev, exec, playerctl previous"
        ",XF86AudioStop, exec, playerctl stop"
        "$mainMod, mouse_down, workspace, e-1"
        "$mainMod, mouse_up, workspace, e+1"
        "$mainMod, S, exec, select-sink"

        # laptop brigthness
        #",XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        #",XF86MonBrightnessDown, exec, brightnessctl set 5%-"
        #"$mainMod, XF86MonBrightnessUp, exec, brightnessctl set 100%+"
        #"$mainMod, XF86MonBrightnessDown, exec, brightnessctl set 100%-"
      ];

      # mouse binding
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # windowrule
      # windowrule = [
      # "float,pqiv"
      # "center,pqiv"
      # "size 1200 725,pqiv"
      # "float,mpv"
      # "center,mpv"
      # "size 1200 725,mpv"
      # "float,audacious"
      # "idleinhibit focus, mpv"
      # "float,udiskie"
      # "float,^(pavucontrol)$"
      # "float,^(blueman-manager)$"
      # "float,^(nm-connection-editor)$"
      # "float,title:^(Transmission)$"
      # "float,title:^(Volume Control)$"
      # "float,title:^(Firefox — Sharing Indicator)$"
      # "float,title:^(OpenSSH Authentication Passphrase request)$"
      # "move 0 0,title:^(Firefox — Sharing Indicator)$"
      # "size 700 450,title:^(Volume Control)$"
      # "move 40 55%,title:^(Volume Control)$"
      # ];

      # windowrulev2
      windowrule = [
        "idleinhibit fullscreen, fullscreenstate:* 2"
        "idleinhibit focus, class:^(mpv)$"
        "idleinhibit fullscreen, title:^(.*Zen Browser.*)$"

        "bordercolor rgb(${colors.red.texthex}) rgb(${colors.peach.texthex}) 45deg, fullscreen:1"

        "opacity 1.0 override 1.0 override, title:^(Picture-in-Picture)$"
        "opacity 1.0 override 1.0 override, title:^(.*pqiv.*)$"
        "opacity 1.0 override 1.0 override, title:^(.*mpv.*)$"
        "opacity 1.0 override 1.0 override, class:(Aseprite)"
        "opacity 1.0 override 1.0 override, class:(Unity)"

        "pin, title:^(Picture-in-Picture)$"

        "center,class:^(zenity)$"

        "size 850 500,class:^(zenity)$"

        "float,class:^(zenity)$"
        "float, title:^(Picture-in-Picture)$"
        "float,class:^(.*pavucontrol)$"
        "float,class:^(qalculate-gtk)$"
        "float,class:^(SoundWireServer)$"
        "float,class:^(.sameboy-wrapped)$"
        "float,class:^(file_progress)$"
        "float,class:^(confirm)$"
        "float,class:^(dialog)$"
        "float,class:^(download)$"
        "float,class:^(notification)$"
        "float,class:^(error)$"
        "float,class:^(confirmreset)$"
        "float,title:^(Open File)$"
        "float,title:^(branchdialog)$"
        "float,title:^(Confirm to replace files)$"
        "float,title:^(File Operation Progress)$"
      ];

      layerrule = [
        "blur, swaync-control-center"
        "blur, swaync-notification-window"
        "ignorezero, swaync-control-center"
        "ignorezero, swaync-notification-window"
        "ignorealpha 0.5, swaync-control-center"
        "ignorealpha 0.5, swaync-notification-window"
      ];

    };
  };
}

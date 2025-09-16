{
  config,
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
        "runapp nm-applet"
        "runapp wl-clip-persist --clipboard both"
        "runapp poweralertd"
        "runapp syshud -p right -o v -m '0 10 0 0'"
        "runapp wl-paste --watch cliphist store"
        "systemctl --user start xdg-desktop-portal-gtk"
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
        no_border_on_floating = false;
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
          };
        }
      ];

      gestures = {
        workspace_swipe_forever = true;
        gesture = "3, horizontal, workspace";
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
        rounding = 12;
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
          ignore_window = true;
          offset = "0 2";
          range = 15;
          render_power = 2;
        };
      };

      animations = {
        enabled = true;

        bezier = [
          "linear, 0, 0, 1, 1"
          "md3_standard, 0.2, 0, 0, 1"
          "md3_decel, 0.05, 0.7, 0.1, 1"
          "md3_accel, 0.3, 0, 0.8, 0.15"
          "overshot, 0.05, 0.9, 0.1, 1.1"
          "crazyshot, 0.1, 1.5, 0.76, 0.92 "
          "hyprnostretch, 0.05, 0.9, 0.1, 1.0"
          "fluent_decel, 0.1, 1, 0, 1"
          "easeInOutCirc, 0.85, 0, 0.15, 1"
          "easeOutCirc, 0, 0.55, 0.45, 1"
          "easeOutExpo, 0.16, 1, 0.3, 1"
        ];

        animation = [
          "windows, 1, 3, md3_decel, popin 60%"
          "border, 1, 10, default"
          "fade, 1, 2.5, md3_decel"
          "workspaces, 1, 3.5, easeOutExpo, slide"
          "specialWorkspace, 1, 3, md3_decel, slidevert"
        ];
      };

      bind = [
        # show keybinds list
        "$mainMod, F1, exec, show-keybinds"

        # app and scrips bindings
        "$mainMod, Return, exec, ghostty +new-window"
        "$mainMod SHIFT, Return, exec, runapp ghostty -e tmux new-session -t 'main'"
        # "$mainMod, Return, exec, uwsm-app -- ghostty -e zellij a -c --index 0"
        # "$mainMod SHIFT, Return, exec, uwsm-app -- ghostty -e tmux"
        # "ALT, Return, exec, uwsm-app -- ghostty +new-window"
        "$mainMod, T, exec, [float; size 950 600] runapp ghostty -e nu -e 'twsync; twl'"
        "$mainMod, D, exec, runapp fuzzel"
        "$mainMod, Q, killactive,"
        "$mainMod, F, fullscreen, 1"
        "$mainMod SHIFT, F, fullscreen, 0"
        "$mainMod, B, exec, runapp vivaldi"
        "$mainMod, Space, exec, toggle_float"
        "$mainMod, Escape, exec, runapp hyprlock"
        "$mainMod SHIFT, Escape, exec, shutdown-script"
        "$mainMod, E, exec, runapp ghostty -e superfile"
        "$mainMod ALT, B, exec, toggle_waybar"
        "$mainMod, C, exec, runapp hyprpicker -a"
        "$mainMod, W, exec, wallchange"
        "$mainMod, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"
        "$mainMod, N, exec, swaync-client -t"
        # "$mainMod, SEMICOLON, exec, uwsm-app -- ghostty -e zellij --layout nvim"

        # dbus global shortcuts
        "ALT, Return, global, com.mitchellh.ghostty:ALT+Return" # toggle_quick_terminal

        # plugins
        # "$mainMod, O, overview:toggle"

        # master layout bindings
        "$mainMod, M, layoutmsg, focusmaster"
        "$mainMod SHIFT, M, layoutmsg, swapwithmaster"
        "$mainMod ALT, M, layoutmsg, addmaster"
        "$mainMod ALT SHIFT, M, layoutmsg, removemaster"
        "$mainMod, TAB, layoutmsg, cyclenext"
        "$mainMod SHIFT, TAB, layoutmsg, cycleprev"

        # screenshot
        "$mainMod, Print, exec, runapp grimblast --notify --freeze save area ~/Pictures/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png"
        "$mainMod, Insert, exec, runapp grimblast --notify --freeze save area ~/Pictures/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png"
        "$mainMod SHIFT, S, exec, runapp grimblast --notify --freeze save area ~/Pictures/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png"
        "$mainMod SHIFT, C, exec, runapp grimblast --notify --freeze copy area"
        ",Print, exec, runapp grimblast --notify --cursor --freeze copy area"
        "ALT, Insert, exec, runapp grimblast --notify --cursor --freeze copy area"

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
        ",XF86AudioRaiseVolume, exec, pamixer -i 5"
        ",XF86AudioLowerVolume, exec, pamixer -d 5"
        ",XF86AudioMute, exec, pamixer -t"
        ",XF86AudioPlay, exec, playerctl play-pause"
        ",XF86AudioNext, exec, playerctl next"
        ",XF86AudioPrev, exec, playerctl previous"
        ",XF86AudioStop, exec, playerctl stop"
        "$mainMod, mouse_down, workspace, e-1"
        "$mainMod, mouse_up, workspace, e+1"
        "$mainMod, S, exec, select-sink"

        # laptop brigthness
        ",XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl set 5%-"
        "$mainMod, XF86MonBrightnessUp, exec, brightnessctl set 100%+"
        "$mainMod, XF86MonBrightnessDown, exec, brightnessctl set 100%-"
        "ALT,XF86AudioRaiseVolume, exec, brightnessctl set 5%+"
        "ALT,XF86AudioLowerVolume, exec, brightnessctl set 5%-"
        "$mainMod ALT, XF86AudioRaiseVolume, exec, brightnessctl set 100%+"
        "$mainMod ALT, XF86AudioLowerVolume, exec, brightnessctl set 100%-"
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
        "idleinhibit fullscreen, title:^(.*Vivaldi.*)$"

        "bordercolor rgb(${config.lib.stylix.colors.base08}) rgb(${config.lib.stylix.colors.base09}) 45deg, fullscreen:1"

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
        # "blur, ^(swaync.*)$"
        # "ignorezero, ^(swaync.*)$"
        # "ignorealpha 0.5, ^(swaync.*)$"
        # "animation popin, ^(swaync.*)$"
      ];
    };
  };
}

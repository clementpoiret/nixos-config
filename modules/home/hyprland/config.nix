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
        "runapp wl-clip-persist --clipboard regular"
        "runapp ghostty --initial-window=false"
        "systemctl --user stop xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk"
        "sleep 0.5 && systemctl --user start xdg-desktop-portal-hyprland"
        "systemctl --user start xdg-desktop-portal-gtk"
        "systemctl --user start xdg-desktop-portal"
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
        layout = "master";
        gaps_in = 8;
        gaps_out = 8;
        border_size = 3;
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
        "SUPER, F1, exec, show-keybinds"

        # app and scrips bindings
        "SUPER, Return, exec, ghostty +new-window"
        "SUPER SHIFT, Return, exec, runapp ghostty -e tmux new-session -t 'main'"
        # "SUPER, Return, exec, uwsm-app -- ghostty -e zellij a -c --index 0"
        # "SUPER SHIFT, Return, exec, uwsm-app -- ghostty -e tmux"
        # "ALT, Return, exec, uwsm-app -- ghostty +new-window"
        "SUPER, T, exec, [float; size 950 600] runapp ghostty -e nu -e 'twsync; twl'"
        "SUPER, D, exec, dms ipc call spotlight toggle"
        "SUPER, Q, killactive,"
        "SUPER, F, fullscreen, 1"
        "SUPER SHIFT, F, fullscreen, 0"
        "SUPER, B, exec, runapp vivaldi"
        "SUPER, Space, exec, toggle_float"
        "SUPER, Escape, exec, dms ipc call lock lock"
        "SUPER SHIFT, Escape, exec, dms ipc call powermenu open"
        "SUPER, E, exec, runapp ghostty -e superfile"
        "SUPER ALT, B, exec, toggle_waybar"
        "SUPER, C, exec, runapp hyprpicker -a"
        "SUPER, W, exec, wallchange"
        # "SUPER, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"
        "SUPER, V, exec, dms ipc call clipboard open"
        "SUPER, N, exec, swaync-client -t"
        # "SUPER, SEMICOLON, exec, uwsm-app -- ghostty -e zellij --layout nvim"
        "SUPER, BACKSPACE, exec, dms ipc call inhibit toggle"

        # dbus global shortcuts
        "ALT, Return, global, com.mitchellh.ghostty:ALT+Return" # toggle_quick_terminal

        # plugins
        # "SUPER, O, overview:toggle"

        # master layout bindings
        "SUPER, M, layoutmsg, focusmaster"
        "SUPER SHIFT, M, layoutmsg, swapwithmaster"
        "SUPER ALT, M, layoutmsg, addmaster"
        "SUPER ALT SHIFT, M, layoutmsg, removemaster"
        "SUPER, TAB, layoutmsg, cyclenext"
        "SUPER SHIFT, TAB, layoutmsg, cycleprev"

        # screenshot
        "SUPER SHIFT, S, exec, runapp quickshell -c hyprquickshot -n"
        ", Print, exec, quickshell -c runapp hyprquickshot -n"

        # switch focus
        "SUPER, left, movefocus, l"
        "SUPER, right, movefocus, r"
        "SUPER, up, movefocus, u"
        "SUPER, down, movefocus, d"
        "SUPER, bracketleft, movefocus, l"
        "SUPER, bracketright, movefocus, r"
        "SUPER, minus, movefocus, u"
        "SUPER, plus, movefocus, d"

        # switch workspace
        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER, 5, workspace, 5"
        "SUPER, 6, workspace, 6"
        "SUPER, 7, workspace, 7"
        "SUPER, 8, workspace, 8"
        "SUPER, 9, workspace, 9"
        "SUPER, 0, workspace, 10"
        "SUPER, mouse_down, workspace, e-1"
        "SUPER, mouse_up, workspace, e+1"

        # same as above, but switch to the workspace
        "SUPER SHIFT, 1, movetoworkspacesilent, 1"
        "SUPER SHIFT, 2, movetoworkspacesilent, 2"
        "SUPER SHIFT, 3, movetoworkspacesilent, 3"
        "SUPER SHIFT, 4, movetoworkspacesilent, 4"
        "SUPER SHIFT, 5, movetoworkspacesilent, 5"
        "SUPER SHIFT, 6, movetoworkspacesilent, 6"
        "SUPER SHIFT, 7, movetoworkspacesilent, 7"
        "SUPER SHIFT, 8, movetoworkspacesilent, 8"
        "SUPER SHIFT, 9, movetoworkspacesilent, 9"
        "SUPER SHIFT, 0, movetoworkspacesilent, 10"
        "SUPER CTRL, c, movetoworkspace, empty"

        # window control
        "SUPER SHIFT, left, movewindow, l"
        "SUPER SHIFT, right, movewindow, r"
        "SUPER SHIFT, up, movewindow, u"
        "SUPER SHIFT, down, movewindow, d"
        "SUPER SHIFT, bracketleft, movewindow, l"
        "SUPER SHIFT, bracketright, movewindow, r"
        "SUPER SHIFT, minus, movewindow, u"
        "SUPER SHIFT, plus, movewindow, d"

        "SUPER CTRL, left, resizeactive, -80 0"
        "SUPER CTRL, right, resizeactive, 80 0"
        "SUPER CTRL, up, resizeactive, 0 -80"
        "SUPER CTRL, down, resizeactive, 0 80"
        "SUPER CTRL, bracketleft, resizeactive, -80 0"
        "SUPER CTRL, bracketright, resizeactive, 80 0"
        "SUPER CTRL, minus, resizeactive, 0 -80"
        "SUPER CTRL, plus, resizeactive, 0 80"

        "SUPER ALT, left, moveactive,  -80 0"
        "SUPER ALT, right, moveactive, 80 0"
        "SUPER ALT, up, moveactive, 0 -80"
        "SUPER ALT, down, moveactive, 0 80"
        "SUPER ALT, h, moveactive,  -80 0"
        "SUPER ALT, j, moveactive, 0 80"
        "SUPER ALT, k, moveactive, 0 -80"
        "SUPER ALT, l, moveactive, 80 0"

        # media and volume controls
        ",XF86AudioRaiseVolume, exec, pamixer -i 5"
        ",XF86AudioLowerVolume, exec, pamixer -d 5"
        ",XF86AudioMute, exec, pamixer -t"
        ",XF86AudioPlay, exec, playerctl play-pause"
        ",XF86AudioNext, exec, playerctl next"
        ",XF86AudioPrev, exec, playerctl previous"
        ",XF86AudioStop, exec, playerctl stop"
        "SUPER, S, exec, select-sink"

        # laptop brigthness
        ",XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl set 5%-"
        "SUPER, XF86MonBrightnessUp, exec, brightnessctl set 100%+"
        "SUPER, XF86MonBrightnessDown, exec, brightnessctl set 100%-"
        "ALT,XF86AudioRaiseVolume, exec, brightnessctl set 5%+"
        "ALT,XF86AudioLowerVolume, exec, brightnessctl set 5%-"
        "SUPER ALT, XF86AudioRaiseVolume, exec, brightnessctl set 100%+"
        "SUPER ALT, XF86AudioLowerVolume, exec, brightnessctl set 100%-"
      ];

      # mouse binding
      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];

      # windowrulev2
      windowrule = [
        "match:fullscreen true, idle_inhibit fullscreen"
        "match:class ^(mpv)$, idle_inhibit focus"
        "match:title ^(.*Zen Browser.*)$, idle_inhibit fullscreen"
        "match:title ^(.*Vivaldi.*)$, idle_inhibit fullscreen"

        "match:fullscreen_state_client 1, border_color rgb(${config.lib.stylix.colors.base08}) rgb(${config.lib.stylix.colors.base09}) 45deg"

        "match:title ^(Picture-in-Picture)$, opacity 1.0 override 1.0 override"
        "match:title ^(.*pqiv.*)$, opacity 1.0 override 1.0 override"
        "match:title ^(.*mpv.*)$, opacity 1.0 override 1.0 override"
        "match:class (Aseprite), opacity 1.0 override 1.0 override"
        "match:class (Unity), opacity 1.0 override 1.0 override"

        "match:title ^(Picture-in-Picture)$, pin on"

        "match:class ^(zenity)$, center on"
        "match:class ^(zenity)$, size 850 500"

        "match:class ^(org.quickshell)$, float on"
        "match:class ^(org.quickshell)$, size 800 500"

        "match:class ^(zenity)$, float on"
        "match:title ^(Picture-in-Picture)$, float on"
        "match:class ^(.*pavucontrol)$, float on"
        "match:class ^(qalculate-gtk)$, float on"
        "match:class ^(SoundWireServer)$, float on"
        "match:class ^(.sameboy-wrapped)$, float on"
        "match:class ^(file_progress)$, float on"
        "match:class ^(confirm)$, float on"
        "match:class ^(dialog)$, float on"
        "match:class ^(download)$, float on"
        "match:class ^(notification)$, float on"
        "match:class ^(error)$, float on"
        "match:class ^(confirmreset)$, float on"
        "match:title ^(Open File)$, float on"
        "match:title ^(branchdialog)$, float on"
        "match:title ^(Confirm to replace files)$, float on"
        "match:title ^(File Operation Progress)$, float on"
      ];

      layerrule = [
        "match:namespace ^(dms)$, no_anim on"
      ];
    };

    extraConfig = ''
      source = ~/.config/hypr/dms/colors.conf
      source = ~/.config/hypr/dms/layout.conf
      source = ~/.config/hypr/dms/outputs.conf
    '';
  };
}

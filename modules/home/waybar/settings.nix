{ ... }:
{
  programs.waybar.settings.mainBar = {
    position = "top";
    layer = "top";
    height = 30;
    spacing = 15;
    margin-top = 0;
    margin-bottom = 0;
    margin-left = 0;
    margin-right = 0;
    modules-left = [
        "custom/launcher" 
        "hyprland/workspaces"
        "cpu"
        "memory"
        "temperature"
        "disk"
    ];
    modules-center= [
        "clock"
    ];
    modules-right= [
        "tray"
        "pulseaudio" 
        "battery"
        "network"
    ];
    clock= {
        timezone = "Europe/Paris";
        calendar = {
          format = { today = "<span color='#b4befe'><b><u>{}</u></b></span>"; };
        };
        format = " {:%H:%M:%S}";
        tooltip= "true";
        tooltip-format= "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format-alt= " {:%d/%m}";
    };
    "hyprland/workspaces"= {
        format = "{icon} {name}";
        format-icons = {
          "active" = "";
          "default" = "";
        };
        on-scroll-up = "hyprctl dispatch workspace e+1";
        on-scroll-down = "hyprctl dispatch workspace e-1";
        on-click = "activate";
    };
    "hyprland/window" = {
        format = "{}";
        separate-outputs = true;
        max-length = 35;
    };
    memory= {
        format= "󰟜 {}%";
        format-alt= "󰟜 {used} GiB"; # 
        interval= 2;
    };
    cpu= {
        format= "  {usage}%";
        format-alt= "  {avg_frequency} GHz";
        interval= 2;
    };
    disk = {
        # path = "/";
        format = "󰋊 {percentage_used}%";
        interval= 60;
    };
    network = {
        format-wifi = "  {signalStrength}%";
        format-ethernet = "󰀂 ";
        tooltip-format = "Connected to {essid} {ifname} via {gwaddr}";
        format-linked = "{ifname} (No IP)";
        format-disconnected = "󰖪 ";
    };
    tray= {
        icon-size = 15;
        spacing = 15;
    };
    pulseaudio= {
        format= "{icon} {volume}%";
        format-muted= "󰖁  {volume}%";
        format-icons= {
            default= [" "];
        };
        scroll-step= 5;
        on-click= "pamixer -t";
    };
    battery = {
        format = "{icon} {capacity}%";
        format-icons = [" " " " " " " " " "];
        format-charging = " {capacity}%";
        format-full = " {capacity}%";
        format-warning = " {capacity}%";
        interval = 5;
        states = {
            warning = 20;
        };
        format-time = "{H}h{M}m";
        tooltip = true;
        tooltip-format = "{time}";
    };
    backlight = {
        # "device": "acpi_video1",
        format = "{percent}% {icon}";
        format-icons = [ "" "" ];
        # on-scroll-up = "/home/cp264607/.config/hypr/scripts/tools/brightness_ctl.sh up";
        # on-scroll-down = "/home/cp264607/.config/hypr/scripts/tools/brightness_ctl.sh down";
        interval = 1;
    };
    "custom/launcher"= {
        format= "";
        on-click= "pkill wofi || wofi --show drun";
        on-click-right= "pkill wofi || wallpaper-picker"; 
        tooltip= "false";
    };
  };
}

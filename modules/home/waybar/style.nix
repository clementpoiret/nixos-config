{ ... }:
let
  theme = import ../theme.nix;
  colors = theme.mocha.colors;

  custom = {
    font = theme.font;
    font_size = "12px";
    font_weight = "500";
    text_color = colors.text.hex;
    secondary_accent = colors.blue.hex;
    tertiary_accent = colors.subtext1.hex;
    background = colors.crust.hex;
    active_background = colors.mantle.hex;
    hover_background = colors.base.hex;
    opacity = "0.98";
  };
in
{
  programs.waybar.style = ''

    * {
        border: none;
        border-radius: 0px;
        padding: 0;
        margin: 0;
        min-height: 0px;
        font-size: ${custom.font_size};
        font-family: ${custom.font};
        font-weight: ${custom.font_weight};
        opacity: ${custom.opacity};
    }

    window#waybar {
        background: transparent;
        color: ${custom.text_color};
        margin: 5px 0;
        font-size: ${custom.font_size};
    }

    #workspaces {
        border-radius: 32px;
        margin: 5px;
        margin-left: 1rem;
    }
    #workspaces button {
        background: ${custom.background};
        color: ${custom.text_color};
        border-radius: 32px;
        border: none;
        margin: 0px 5px;
        padding: 0px 10px;
        transition: all 0.5s cubic-bezier(0.33, 1.0, 0.68, 1.0); /* easeInOutCubic */
    }
    #workspaces button.active {
        color: #b4befe;
        border-radius: 32px;
        padding: 0rem 1rem;
    }
    #workspaces button.empty {
        color: #b4befe;
        border-radius: 32px;
    }
    #workspaces button:hover {
        box-shadow: none; /* Remove predefined box-shadow */
        text-shadow: none; /* Remove predefined text-shadow */
        background: ${custom.hover_background};
        padding: 0rem 1rem;
    }

    #window,
    #tray,
    #backlight,
    #pulseaudio,
    #network,
    #mpd,
    #cpu,
    #memory,
    #disk,
    #temperature,
    #idle_inhibitor,
    #clock,
    #power-profiles-daemon,
    #battery,
    #custom-fancontrol,
    #custom-music,
    #custom-launcher,
    #custom-updates,
    #custom-hyprsunset,
    #custom-suspend,
    #custom-notifications,
    #custom-notification,
    #custom-power,
    #custom-weather {
        /* background: ${custom.background}; */
        font-size: ${custom.font_size};
        color: ${custom.text_color};
        border-radius: 1rem;
        padding: 0.5rem 1rem;
        margin: 5px 0;
    }

    #battery {
       /* color: @green; */
    }
    #battery.charging {
       /* color: @green; */
    }
    #battery.warning:not(.charging) {
       /* color: @maroon; */
    }
    #battery.critical:not(.charging) {
       /* color: @red; */
    }

    #backlight {
        padding-right: 1.25rem;
    }

    #cpu {
        padding-left: 15px;
        padding-right: 9px;
        margin-left: 7px;
    }
    #memory {
        padding-left: 9px;
        padding-right: 9px;
    }
    #disk {
        padding-left: 9px;
        padding-right: 15px;
    }

    #tray {
        padding: 0 20px;
        margin-left: 7px;
    }

    #pulseaudio {
        padding-left: 15px;
        padding-right: 9px;
        margin-left: 7px;
    }
    #network {
        padding-left: 9px;
        padding-right: 15px;
    }

    #clock {
        padding-left: 9px;
        padding-right: 15px;
    }

    #custom-launcher {
        font-size: 16px;
        color: #b4befe;
        font-weight: ${custom.font_weight};
        padding-left: 10px;
        padding-right: 15px;
    }

    custom-notification {
        padding-left: 20px;
        padding-right: 20px;
    }
  '';
}

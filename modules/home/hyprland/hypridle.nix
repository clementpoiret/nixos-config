{
  host,
  inputs,
  pkgs,
  ...
}:
{
  services.hypridle = {
    enable = true;
    package = inputs.hypridle.packages.${pkgs.system}.hypridle;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        ignore_systemd_inhibit = false;
        lock_cmd = "pidof hyprlock || hyprlock";
      };
      listener =
        let
          commonListeners = [
            {
              timeout = 300; # 5min
              on-timeout = "pidof hyprlock || hyprlock";
            }
            # TODO: Fix systemd suspend on desktop
          ];
          laptopListeners = [
            {
              timeout = 150; # 2.5min.
              on-timeout = "brightnessctl -s set 10";
              on-resume = "brightnessctl -r";
            }
            {
              timeout = 330; # 5.5min
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
            {
              timeout = 900; # 15min
              on-timeout = "systemctl suspend";
            }
          ];
        in
        if host == "laptop" then laptopListeners ++ commonListeners else commonListeners;
    };
  };
}

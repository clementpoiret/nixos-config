{
  host,
  pkgs,
  ...
}:
{
  services.hypridle = {
    enable = true;
    package = pkgs.hypridle;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        ignore_systemd_inhibit = false;
        lock_cmd = "pidof hyprlock || runapp hyprlock";
      };
      listener =
        let
          commonListeners = [
            {
              timeout = 600; # 10min
              on-timeout = "pidof hyprlock || runapp hyprlock";
            }
            {
              timeout = 1200; # 20min
              on-timeout = "systemctl suspend";
            }
          ];
          laptopListeners = [
            {
              timeout = 180; # 3min.
              on-timeout = "brightnessctl -s set 10";
              on-resume = "brightnessctl -r";
            }
            {
              timeout = 360; # 6min
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
          ];
        in
        if host == "laptop" then laptopListeners ++ commonListeners else commonListeners;
    };
  };
}

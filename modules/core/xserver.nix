{ ... }:
{
  services = {
    xserver = {
      enable = true;
      autorun = false;
      xkb.layout = "fr(ergol)";
      displayManager.startx.enable = true;
    };

    # displayManager.autoLogin = {
    # enable = false;
    # user = "${username}";
    # };

    libinput = {
      enable = true;
      # mouse = {
      #  accelProfile = "flat";
      # };
    };
  };

  console = {
    useXkbConfig = true;
    # keyMap = "fr(ergol)";
  };

  # To prevent getting stuck at shutdown
  systemd.settings.Manager = {
    DefaultIOAccounting = true;
    DefaultIPAccounting = true;
    DefaultTimeoutStopSec = "10s";
  };
}

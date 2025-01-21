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
  systemd.extraConfig = "DefaultTimeoutStopSec=10s";
}

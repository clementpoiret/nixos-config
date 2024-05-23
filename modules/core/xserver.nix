{ pkgs, username, ... }: 
{
  services = {
    xserver = {
      enable = true;
      autorun = false;
      xkb.layout = "us";
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

  # To prevent getting stuck at shutdown
  systemd.extraConfig = "DefaultTimeoutStopSec=10s";
}

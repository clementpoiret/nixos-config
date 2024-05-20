{ pkgs, username, ... }: 
{
  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
    };

    displayManager.autoLogin = {
      enable = false;
      user = "${username}";
    };

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

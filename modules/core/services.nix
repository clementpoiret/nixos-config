{ ... }:
{
  services = {
    gvfs.enable = true;
    gnome.gnome-keyring.enable = true;
    dbus = {
      enable = true;
      implementation = "broker";
    };
    #fstrim.enable = true;
  };
  services.logind.extraConfig = ''
    # don’t shutdown when power button is short-pressed
    HandlePowerKey=ignore
  '';

  services.syncthing = {
    enable = true;
    user = "clementpoiret";
    dataDir = "/home/clementpoiret/Sync/";
  };
}

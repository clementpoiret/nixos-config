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
  services.logind.settings.Login = {
    HandlePowerekey = "ignore";
  };

  services.syncthing = {
    enable = true;
    user = "clementpoiret";
    dataDir = "/home/clementpoiret/Sync/";
  };
}

{ pkgs, ... }:
{
  services = {
    gvfs.enable = true;
    gnome.gnome-keyring.enable = false;
    dbus = {
      enable = true;
      implementation = "broker";
      packages = [ pkgs.kdePackages.kwallet ];
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

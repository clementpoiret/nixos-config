{ pkgs, ... }:
{
  services = {
    gvfs.enable = true;
    dbus = {
      enable = true;
      implementation = "broker";
      packages = with pkgs; [
        gcr
        gnome-keyring
        libsecret
        seahorse
      ];
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

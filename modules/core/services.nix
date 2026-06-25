{ pkgs, username, ... }:
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

  services.syncthing = {
    enable = true;
    user = username;
    dataDir = "/home/${username}/Sync/";
  };
}

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
    journald.extraConfig = ''
      Storage=persistent
      Compress=yes
      Seal=yes
      SystemMaxUse=1G
      MaxRetentionSec=30day
      RateLimitIntervalSec=30s
      RateLimitBurst=10000
    '';
    timesyncd.enable = false;
    chrony = {
      enable = true;
      enableNTS = true;
      servers = [
        "time.cloudflare.com"
        "nts.netnod.se"
        "ptbtime1.ptb.de"
      ];
    };
    #fstrim.enable = true;
  };

  services.syncthing = {
    enable = true;
    user = username;
    dataDir = "/home/${username}/Sync/";
    openDefaultPorts = false;
  };
}

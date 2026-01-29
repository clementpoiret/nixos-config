{ pkgs, ... }:
{
  security.rtkit.enable = true;
  security.sudo.enable = true;
  security.polkit.enable = true;
  security.pki.certificateFiles = [
    ../../certs/cert.pem
  ];

  environment.systemPackages = with pkgs; [
    libsecret
    gnome-keyring
    seahorse
  ];

  programs.seahorse.enable = true;
  security.pam = {
    services = {
      login = {
        u2fAuth = true;
        enableGnomeKeyring = true;
      };
      sudo = {
        u2fAuth = true;
      };

      hyprlock = { };
    };
    u2f = {
      enable = true;
      settings = {
        interactive = true;
        cue = true;
      };
    };
  };

  services.udev.extraRules = ''
    ACTION=="remove",\
     ENV{ID_BUS}=="usb",\
     ENV{ID_MODEL_ID}=="0407",\
     ENV{ID_VENDOR_ID}=="1050",\
     ENV{ID_VENDOR}=="Yubico",\
     RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"
  '';
}

# Secure Boot enrollment is prepared automatically after this configuration is
# booted. Enter firmware Setup Mode before booting it for the first time.

{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  environment.systemPackages = [ pkgs.sbctl ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoEnrollKeys = {
      enable = true;
      autoReboot = false;
    };
  };
}

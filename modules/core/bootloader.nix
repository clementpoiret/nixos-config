{ config, host, lib, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.kernelPackages = pkgs.linuxPackages_zen;

  boot.extraModulePackages = with config.boot.kernelPackages; lib.mkIf (host == "laptop") [
    framework-laptop-kmod
  ];
  boot.kernelModules = lib.mkIf (host == "laptop") [
    "cros_ec"
    "cros_ec_lpcs"
  ];
}

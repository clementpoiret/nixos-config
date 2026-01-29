{
  config,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # To fix WiFi with Qualcomm QCNCM865 / WCN785x (must be linux 6.13.x or lower, or 6.16+)
  # linuxPackage =
  #   if (host == "laptop") then pkgs.linuxPackages_cachyos-rc else pkgs.linuxPackages_cachyos-lto;
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-zen4;
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
    extraArgs = [ "--autopower" ];
  };

  boot.extraModulePackages =
    with config.boot.kernelPackages;
    lib.mkIf (host == "laptop") [ framework-laptop-kmod ];
  boot.kernelModules = lib.mkIf (host == "laptop") [
    "cros_ec"
    "cros_ec_lpcs"
  ];
}

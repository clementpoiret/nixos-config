{
  config,
  host,
  lib,
  pkgs,
  ...
}:
let
  # To fix WiFi with Qualcomm QCNCM865 / WCN785x (must be linux 6.13.x or lower)
  linuxPackage =
    if (host == "laptop") then pkgs.linuxPackages_xanmod else pkgs.linuxPackages_cachyos-lto;
  enableScx = (host != "laptop");
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.kernelPackages = linuxPackage;
  services.scx = lib.mkIf enableScx {
    enable = true;
    package = pkgs.scx.full;
    scheduler = "scx_bpfland";
  };

  boot.extraModulePackages =
    with config.boot.kernelPackages;
    lib.mkIf (host == "laptop") [ framework-laptop-kmod ];
  boot.kernelModules = lib.mkIf (host == "laptop") [
    "cros_ec"
    "cros_ec_lpcs"
  ];
}

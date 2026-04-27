{
  config,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  isLaptop = host == "laptop";
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
    lib.mkIf isLaptop [ framework-laptop-kmod ];
  boot.kernelModules = lib.mkIf (host == "laptop") [
    "cros_ec"
    "cros_ec_lpcs"
    "framework_laptop"
  ];

  services.ananicy = lib.mkIf isLaptop {
    enable = true;

    # Use the C++ daemon, not the original shell implementation.
    package = pkgs.ananicy-cpp;

    # Use CachyOS' ruleset.
    rulesProvider = pkgs.ananicy-rules-cachyos;

    settings = {
      loglevel = "warn";
      log_applied_rule = false;

      # I would start with this false on a NixOS + systemd + sched-ext laptop.
      # It avoids the RT-cgroup workaround that upstream CachyOS rules warn can
      # cause issues with things like polkit.
      cgroup_realtime_workaround = lib.mkForce false;
    };
  };

}

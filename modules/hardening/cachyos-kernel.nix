# Host-aware CachyOS kernel profile.
#
# Desktop: latest CachyOS kernel, 500 Hz.
# Laptop:  CachyOS LTS kernel, 300 Hz and lazy RCU.
# Both:    EEVDF, Clang ThinLTO, KCFI, NO_HZ_IDLE, full preemption,
#          Zen 4 optimization, THP madvise.
#
# This is a custom derivation and may not be present in the CachyOS binary
# cache. Keep the generated cached-CachyOS and stock-NixOS specialisations.

{
  host,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  isLaptop = host == "laptop";

  baseKernel =
    if isLaptop then
      pkgs.cachyosKernels.linux-cachyos-lts
    else
      pkgs.cachyosKernels.linux-cachyos-latest;

  customKernel = baseKernel.override {
    lto = "thin";
    processorOpt = "zen4";

    cpusched = "eevdf";
    kcfi = true;
    hzTicks = if isLaptop then "300" else "500";
    performanceGovernor = false;
    tickrate = "idle";
    preemptType = "full";
    ccHarder = true;
    bbr3 = false;
    hugepage = "madvise";
    autoModules = true;
  };

  cachyosHelpers = pkgs.callPackage "${inputs.nix-cachyos-kernel.outPath}/helpers.nix" { };
  customKernelPackages = cachyosHelpers.kernelModuleLLVMOverride (
    pkgs.linuxKernel.packagesFor customKernel
  );

  cachedKernelPackages =
    if isLaptop then
      pkgs.cachyosKernels.linuxPackages-cachyos-lts-lto-zen4
    else
      pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-zen4;
in
{
  # Override the repository's current generic latest-CachyOS selection, while
  # still allowing the recovery specialisations below to use mkForce.
  boot.kernelPackages = lib.mkOverride 60 customKernelPackages;

  boot.kernelParams = [
    "transparent_hugepage=madvise"
  ]
  ++ lib.optionals isLaptop [
    "rcutree.enable_rcu_lazy=1"
  ];

  # Cached fallback: same release input and Zen 4 ThinLTO package, but without
  # the custom KCFI/tick/THP changes. Useful if a local kernel build fails.
  specialisation.cached-cachyos.configuration = {
    system.nixos.tags = [ "cached-cachyos" ];
    boot.kernelPackages = lib.mkForce cachedKernelPackages;
  };

  # Independent upstream-NixOS LTS fallback. Retain at least one generation
  # containing this specialisation before testing module enforcement or KCFI.
  specialisation.stock-nixos-lts.configuration = {
    system.nixos.tags = [ "stock-nixos-lts" ];
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
  };
}

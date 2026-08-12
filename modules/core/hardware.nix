{
  host,
  inputs,
  hostFacts,
  lib,
  pkgs,
  ...
}:
let
  isLaptop =
    if host == "laptop" then
      true
    else if host == "desktop" then
      false
    else
      throw "modules/core/hardware.nix: unsupported host '${host}'";

  baseKernel = pkgs.cachyosKernels.linux-cachyos-latest;
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
  cachedKernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-zen4;
in
{
  imports = [ inputs.ucodenix.nixosModules.default ];

  boot = {
    # This custom profile may require a local build. Keep the cached CachyOS
    # profile as a bootable fallback for updates and module regressions.
    kernelPackages = customKernelPackages;
    kernelParams = [
      "transparent_hugepage=madvise"
    ]
    ++ lib.optionals isLaptop [
      "rcutree.enable_rcu_lazy=1"
    ];

    # performance tweaks
    kernel.sysctl = {
      "vm.swappiness" = 100;
      "vm.page-cluster" = 0;
      "vm.vfs_cache_pressure" = 50;
      "vm.dirty_background_ratio" = 5;
      "vm.dirty_ratio" = 10;

      # TCP Fast Open
      "net.ipv4.tcp_fastopen" = 3;
      # Increase network performance
      "net.core.netdev_max_backlog" = 16384;
      "net.ipv4.tcp_max_syn_backlog" = 8192;
      "net.core.somaxconn" = 8192;
      # BBR TCP congestion control
      "net.core.default_qdisc" = "cake";
      "net.ipv4.tcp_congestion_control" = "bbr";

      # This is a diagnostics/performance choice, not a hardening control. Turn
      # it back on temporarily when investigating hard lockups.
      "kernel.nmi_watchdog" = 0;
    };

    # /tmp as tmpfs
    tmp = {
      useTmpfs = true;
      # tmpfsSize = "50%";
    };
  };

  specialisation.cached-cachyos.configuration = {
    system.nixos.tags = [ "cached-cachyos" ];
    boot.kernelPackages = lib.mkForce cachedKernelPackages;
  };

  services = {
    scx = {
      enable = true;
      scheduler = "scx_lavd";
    };

    udev.extraRules = ''
      # Set scheduler for NVMe
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
      # Set scheduler for SATA SSD
      ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
      # Set scheduler for HDD
      ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
    '';

    # Firmware updates
    fwupd = {
      enable = true;
      # Deliberate exception: testing metadata is required for selected signed
      # device firmware and remains opt-in at update time.
      extraRemotes = [ "lvfs-testing" ];
    };

    # ucode updates
    ucodenix = {
      enable = true;
      cpuModelId = hostFacts.hardware.cpuModelId;
    };
  };

  hardware = {
    graphics.enable = true;
    enableRedistributableFirmware = true;
  };
}

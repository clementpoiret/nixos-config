{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./rocm.nix
    ./../../modules/core
    ./../../modules/features/bluetooth.nix
    ./../../modules/features/development-hardware.nix
    ./../../modules/features/virtualization.nix
    ./../../modules/features/xwayland.nix
  ];

  environment.systemPackages = with pkgs; [
    acpi
    brightnessctl
    cpupower-gui
    powertop
  ];

  services = {
    scx.extraArgs = [ "--autopower" ];

    # thermald.enable = true;
    # cpupower-gui.enable = true;
    ananicy = {
      enable = true;

      # Use the C++ daemon, not the original shell implementation.
      package = pkgs.ananicy-cpp;

      # Use CachyOS' ruleset.
      rulesProvider = pkgs.ananicy-rules-cachyos;

      settings = {
        loglevel = "warn";
        log_applied_rule = false;
        cgroup_realtime_workaround = lib.mkForce false;
      };
    };

    upower = {
      enable = true;
      percentageLow = 20;
      percentageCritical = 5;
      percentageAction = 3;
      criticalPowerAction = "PowerOff";
    };

    logind.settings.Login = {
      HandlePowerKey = "hibernate";
      HandlePowerKeyLongPress = "poweroff";
      HandleLidSwitch = "suspend-then-hibernate";
    };
  };
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "30m";
    MemorySleepMode = "s2idle";
    SuspendState = "mem";
  };

  boot = {
    lanzaboote.autoEnrollKeys.includeFirmwareBuiltinKeys = true;

    blacklistedKernelModules = [ "k10temp" ];
    kernelModules = [
      "acpi_call"
      "framework_laptop"
    ];
    kernelParams = [
      # Re-enable S/G display; restore this workaround if display corruption returns.
      # "amdgpu.sg_display=0"

      # Deliberate exception: the pinned ucodenix blob fails the kernel SHA
      # allowlist; its exact provenance and hash remain recorded in flake.lock.
      # "microcode.amd_sha_check=off"

      # Optional strict trial, only after `acpi_call` and every other external
      # module reports a signer trusted by the running kernel.
      # "module.sig_enforce=1"

      # hibernation
      # run0 -- btrfs inspect-internal map-swapfile -r /var/lib/swapfile
      "resume_offset=10238424"
    ];

    # hibernation
    resumeDevice = "/dev/disk/by-uuid/caf8fdb0-bbd6-4f1d-a2f0-8a1c48f6f548";

    extraModulePackages =
      with config.boot.kernelPackages;
      [
        acpi_call
        cpupower
      ]
      ++ [ pkgs.cpupower-gui ];

    kernel.sysctl."kernel.kexec_load_disabled" = 1;
  };

  # Hibernation
  powerManagement.enable = true;
  security.protectKernelImage = false;
  # Optional strict trial after preloading every module required by Framework
  # expansion cards, docks, VPNs, virtualization, and hibernation.
  # security.lockKernelModules = true;

  networking.networkmanager.wifi = {
    powersave = true;
    scanRandMacAddress = true;
    macAddress = "stable-ssid";
  };

  # Do not enable Linux Lockdown while hibernation remains required. See
  # docs/HARDENING.md for the compatibility and recovery procedure.

  # nixos-hardware enables this for compatibility; this host deliberately
  # keeps the 32-bit graphics ABI disabled.
  hardware.graphics.enable32Bit = lib.mkForce false;

  services.udev.extraRules = ''
    # Framework Laptop Webcam Module (2nd Gen)
    ACTION=="add", SUBSYSTEM=="video4linux", ENV{ID_V4L_CAPABILITIES}=="*:capture:*", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="001c", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl --device=/dev/%k --set-ctrl=saturation=50"

    # AMD dGPU (Navi 33) by PCI slot
    KERNEL=="card*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:03:00.0", SYMLINK+="dri/amd-dgpu"
    KERNEL=="renderD*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:03:00.0", SYMLINK+="dri/amd-dgpu-render"

    # AMD iGPU (Phoenix1) by PCI slot
    KERNEL=="card*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:c5:00.0", SYMLINK+="dri/amd-igpu"
    KERNEL=="renderD*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:c5:00.0", SYMLINK+="dri/amd-igpu-render"
  '';
}

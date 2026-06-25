{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
  ];

  environment.systemPackages = with pkgs; [
    acpi
    brightnessctl
    cpupower-gui
    powertop
  ];

  services = {
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
      powerKey = "hibernate";
      powerKeyLongPress = "poweroff";
      lidSwitch = "suspend-then-hibernate";
    };
  };
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "30m";
    SuspendState = "mem";
  };

  boot = {
    blacklistedKernelModules = [ "k10temp" ];
    kernelModules = [
      "acpi_call"
      "framework_laptop"
    ];
    kernelParams = [
      "amdgpu.sg_display=0"

      "microcode.amd_sha_check=off" # microcode from ucodenix couldn't be loaded without this

      "mem_sleep_default=deep"

      # hibernation
      # sudo btrfs inspect-internal map-swapfile -r /var/lib/swapfile
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
  };

  # Hibernation
  powerManagement.enable = true;

  services.udev.extraRules = ''
    # AMD dGPU (Navi 33) by PCI slot
    KERNEL=="card*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:03:00.0", SYMLINK+="dri/amd-dgpu"
    KERNEL=="renderD*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:03:00.0", SYMLINK+="dri/amd-dgpu-render"

    # AMD iGPU (Phoenix1) by PCI slot
    KERNEL=="card*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:c5:00.0", SYMLINK+="dri/amd-igpu"
    KERNEL=="renderD*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:c5:00.0", SYMLINK+="dri/amd-igpu-render"
  '';
}

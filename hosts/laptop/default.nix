{ pkgs, config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
  ];

  environment.etc = {
    "libinput/local-overrides.quirks".text = ''
      [Keyboard]
      MatchUdevType=keyboard
      MatchName=Framework Laptop 16 Keyboard Module - ANSI Keyboard
      AttrKeyboardIntegration=internal
    '';
  };

  environment.systemPackages = with pkgs; [
    acpi
    brightnessctl
    cpupower-gui
    framework-tool
    powertop
  ];

  services = {
    # thermald.enable = true;
    # cpupower-gui.enable = true;
    power-profiles-daemon.enable = true;

    fprintd.enable = true;

    upower = {
      enable = true;
      percentageLow = 20;
      percentageCritical = 5;
      percentageAction = 3;
      criticalPowerAction = "PowerOff";
    };
  };

  boot = {
    blacklistedKernelModules = [ "k10temp" ];
    kernelModules = [
      "acpi_call"
      "cros_ec"
      "cros_ec_lpcs"
      # "zenpower"
    ];
    kernelParams = [
      "amd_pstate=active"
      "amdgpu.sg_display=0"
      # There seems to be an issue with panel self-refresh (PSR) that
      # causes hangs for users.
      #
      # https://community.frame.work/t/fedora-kde-becomes-suddenly-slow/58459
      # https://gitlab.freedesktop.org/drm/amd/-/issues/3647
      "amdgpu.dcdebugmask=0x10"

      "microcode.amd_sha_check=off" # microcode from ucodenix couldn't be loaded without this
    ];
    extraModulePackages =
      with config.boot.kernelPackages;
      [
        acpi_call
        cpupower
        framework-laptop-kmod
        # zenpower
      ]
      ++ [ pkgs.cpupower-gui ];
  };

  hardware.sensor.iio.enable = true;
  hardware.keyboard.qmk.enable = true;

  services.udev.extraRules = ''
    # AMD dGPU (Navi 33) by PCI slot
    KERNEL=="card*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:03:00.0", SYMLINK+="dri/amd-dgpu"
    KERNEL=="renderD*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:03:00.0", SYMLINK+="dri/amd-dgpu-render"

    # AMD iGPU (Phoenix1) by PCI slot
    KERNEL=="card*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:c5:00.0", SYMLINK+="dri/amd-igpu"
    KERNEL=="renderD*", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", KERNELS=="0000:c5:00.0", SYMLINK+="dri/amd-igpu-render"
  '';
}

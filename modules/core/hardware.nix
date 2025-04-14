{
  inputs,
  config,
  host,
  lib,
  pkgs,
  ...
}:
let
  xserverDrivers = {
    "desktop" = "nvidia";
    "laptop" = "amdgpu";
  };

  # from `cpuid -1 -l 1 -r | sed -n 's/.*eax=0x\([0-9a-f]*\).*/\U\1/p'`
  cpuModelId = {
    "desktop" = "00870F10";
    "laptop" = "00A70F41";
  };
in
{
  imports = [ inputs.ucodenix.nixosModules.default ];

  # performance tweaks
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
    "kernel.nmi_watchdog" = 0;

    # TCP Fast Open
    "net.ipv4.tcp_fastopen" = 3;
    # Increase network performance
    "net.core.netdev_max_backlog" = 16384;
    "net.ipv4.tcp_max_syn_backlog" = 8192;
    "net.core.somaxconn" = 8192;
    # BBR TCP congestion control
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  services.udev.extraRules = ''
    # Set scheduler for NVMe
    ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
    # Set scheduler for SATA SSD
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
    # Set scheduler for HDD
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"

    # This is for picotool
    SUBSYSTEM=="usb", \
      ATTRS{idVendor}=="2e8a", \
      ATTRS{idProduct}=="0003", \
      TAG+="uaccess" \
      MODE="660", \
      GROUP="plugdev"
    SUBSYSTEM=="usb", \
      ATTRS{idVendor}=="2e8a", \
      ATTRS{idProduct}=="0009", \
      TAG+="uaccess" \
      MODE="660", \
      GROUP="plugdev"
    SUBSYSTEM=="usb", \
      ATTRS{idVendor}=="2e8a", \
      ATTRS{idProduct}=="000a", \
      TAG+="uaccess" \
      MODE="660", \
      GROUP="plugdev"
    SUBSYSTEM=="usb", \
      ATTRS{idVendor}=="2e8a", \
      ATTRS{idProduct}=="000f", \
      TAG+="uaccess" \
      MODE="660", \
      GROUP="plugdev"
  '';

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.extraPackages =
    with pkgs;
    lib.mkIf (host == "laptop") [
      amdvlk
      # TODO: Switch back to unstable after the following issue is fixed:
      # https://github.com/NixOS/nixpkgs/issues/369433
      rocmPackages.clr
    ];
  hardware.graphics.extraPackages32 =
    with pkgs;
    lib.mkIf (host == "laptop") [
      driversi686Linux.amdvlk
    ];

  # nvidia and amdgpu
  services.xserver.videoDrivers = [ xserverDrivers."${host}" ];

  hardware.nvidia = lib.mkIf (host == "desktop") {
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    modesetting.enable = true;
    powerManagement.enable = true;
    # powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
  };

  environment.variables = lib.mkIf (host == "desktop") {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
  };

  # bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Firmware updates
  services.fwupd.enable = true;

  # ucode updates
  services.ucodenix = {
    enable = true;
    cpuModelId = cpuModelId.${host};
  };

  # /tmp as tmpfs
  boot.tmp = {
    useTmpfs = true;
    # tmpfsSize = "50%";
  };

  # Needed for desktop environments to detect/manage display brightness
  hardware.sensor.iio.enable = lib.mkIf (host == "laptop") true;

  hardware.keyboard.qmk.enable = true;

  # Allow `services.libinput.touchpad.disableWhileTyping` to work correctly.
  # Set unconditionally because libinput can also be configured dynamically via
  # gsettings.
  environment.etc = lib.mkIf (host == "laptop") {
    "libinput/local-overrides.quirks".text = ''
      [Serial Keyboards]
      MatchUdevType=keyboard
      MatchName=Framework Laptop 16 Keyboard Module - ANSI Keyboard
      AttrKeyboardIntegration=internal
    '';
  };

  hardware.flipperzero.enable = true;
}

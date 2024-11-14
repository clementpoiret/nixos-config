{ inputs, config, host, lib, pkgs, ... }:
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

  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.extraPackages = with pkgs; lib.mkIf (host == "laptop") [
    amdvlk
    rocmPackages.clr
  ];
  hardware.graphics.extraPackages32 = with pkgs; lib.mkIf (host == "laptop") [
    driversi686Linux.amdvlk
  ];

  # nvidia and amdgpu
  services.xserver.videoDrivers = [ xserverDrivers."${host}" ];

  hardware.nvidia = lib.mkIf (host == "desktop") {
    # package = config.boot.kernelPackages.nvidiaPackages.beta;
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    # open = true;
    open = false;
    nvidiaSettings = true;
  };

  environment.variables = lib.mkIf (host == "desktop") {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "0";
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

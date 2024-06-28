{ config, host, lib, pkgs, ... }:
{  
  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.extraPackages = with pkgs; lib.mkIf (host == "laptop") [
    amdvlk
    rocm-opencl-icd
    rocm-opencl-runtime 
  ];
  hardware.graphics.extraPackages32 = with pkgs; lib.mkIf (host == "laptop") [
    driversi686Linux.amdvlk
  ];

  # nvidia
  services.xserver.videoDrivers = lib.mkIf (host == "desktop") [ "nvidia" ];

  hardware.nvidia = lib.mkIf (host == "desktop") {
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
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

  # f2fs check
  #boot.initrd = lib.mkIf (host == "desktop") {
  #  checkJournalingFS = false; 
  #};
}

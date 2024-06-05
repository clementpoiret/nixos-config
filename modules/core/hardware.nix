{ config, host, lib, pkgs, ... }:
{  
  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.enableRedistributableFirmware = true;
  hardware.opengl.extraPackages = with pkgs; lib.mkIf (host == "laptop") [
    amdvlk
    rocm-opencl-icd
    rocm-opencl-runtime 
  ];
  hardware.opengl.extraPackages32 = with pkgs; lib.mkIf (host == "laptop") [
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

{ config, host, lib, pkgs, ... }:
{  
  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.enableRedistributableFirmware = true;
  hardware.opengl.extraPackages = with pkgs; [
  ];

  # nvidia
  #services.xserver.videoDrivers = [ "nvidia" ];

  #hardware.nvidia = {
  #  package = config.boot.kernelPackages.nvidiaPackages.beta;
  #  modesetting.enable = true;
  #  powerManagement.enable = false;
  #  powerManagement.finegrained = false;
  #  open = true;
  #  nvidiaSettings = true;
  #};

  # bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # f2fs check
  boot.initrd = lib.mkIf (host == "desktop") {
    checkJournalingFS = false; 
  };
}

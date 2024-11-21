{ pkgs, ... }: 
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
  ];

  powerManagement.cpuFreqGovernor = "performance";

  boot.kernelParams = [ "nvidia_drm.modeset=1" "fbdev=1" ];
}

{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
  ];

  powerManagement.cpuFreqGovernor = "performance";

  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "fbdev=1"
    "microcode.amd_sha_check=off" # microcode from ucodenix couldn't be loaded without this
  ];
}

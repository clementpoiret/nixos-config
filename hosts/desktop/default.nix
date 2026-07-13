{
  config,
  username,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
  ];

  powerManagement.cpuFreqGovernor = "performance";

  boot.kernelParams = [
    "amd_pstate=active"
    "microcode.amd_sha_check=off" # microcode from ucodenix couldn't be loaded without this
  ];

  hardware.amdgpu.initrd.enable = true;

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = false;
    powerManagement.enable = true;
    open = true;
    nvidiaSettings = true;
  };

  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="renderD*", DRIVERS=="amdgpu", SYMLINK+="dri/amd-igpu-render"
  '';

  home-manager.users.${username}.programs.niri.settings.debug.render-drm-device =
    "/dev/dri/amd-igpu-render";
}

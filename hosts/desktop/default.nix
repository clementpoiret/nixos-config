{
  config,
  lib,
  username,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./performance.nix
    ./../../modules/core
    ./../../modules/features/bluetooth.nix
    ./../../modules/features/desktop-compatibility.nix
    ./../../modules/features/development-hardware.nix
    ./../../modules/features/virtualization.nix
    ./../../modules/features/xwayland.nix
  ];

  boot.kernelParams = [
    "amd_pstate=active"
    # Deliberate exception: the pinned ucodenix blob fails the kernel SHA
    # allowlist; its exact provenance and hash remain recorded in flake.lock.
    # "microcode.amd_sha_check=off"

    # Optional strict trials. Validate every NVIDIA module signer before the
    # first option; enable Lockdown only on this non-hibernating host.
    # "module.sig_enforce=1"
    # "lockdown=integrity"
  ];

  security.protectKernelImage = true;
  # Optional strict trial after inventorying and preloading every required
  # hotplug, VPN, VM, filesystem, and development-device module.
  # security.lockKernelModules = true;

  networking.firewall.interfaces."virbr0" = lib.mkIf config.virtualisation.libvirtd.enable {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [
      53
      67
    ];
  };

  environment.etc."crypttab".text = ''
    crypt-syncthing UUID=b2a3176d-92eb-4df4-b20f-3bb2c1a77229 none luks,discard
    crypt-cache     UUID=80c11c8a-d26d-4a9a-9782-9c38de05fa72 none luks,discard
  '';

  fileSystems."/srv/syncthing" = {
    device = "/dev/mapper/crypt-syncthing";
    fsType = "btrfs";
    options = [
      "noatime"
      "compress=zstd:3"
      "discard=async"
    ];
  };

  fileSystems."/cache" = {
    device = "/dev/mapper/crypt-cache";
    fsType = "btrfs";
    options = [
      "noatime"
      "compress=zstd:1"
      "discard=async"
    ];
  };

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

  home-manager.users.${username}.programs.niri.settings.debug = {
    render-drm-device = "/dev/dri/amd-igpu-render";
    ignore-drm-device = "/dev/dri/by-path/pci-0000:01:00.0-render";
  };
}

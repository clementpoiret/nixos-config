{
  pkgs,
  username,
  ...
}:
{
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      # Required for containers under podman-compose to communicate by name.
      defaultNetwork.settings.dns_enabled = true;
    };

    libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };

    virtualbox.host = {
      enable = true;
      enableExtensionPack = true;
    };
  };

  users.users.${username}.extraGroups = [
    "libvirtd"
    "podman"
    "vboxusers"
  ];

  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    dnsmasq
    virt-viewer
  ];
}

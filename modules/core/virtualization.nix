{
  pkgs,
  username,
  ...
}:
{
  # Manage the virtualisation services
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
    };

    libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
      };
    };
  };

  # Add user to libvirtd group
  users.users.${username}.extraGroups = [
    "libvirtd"
    "podman"
  ];

  programs.virt-manager.enable = true;

  # Install necessary packages
  environment.systemPackages = with pkgs; [
    dnsmasq
    virt-viewer
  ];
}

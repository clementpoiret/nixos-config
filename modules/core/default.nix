{ ... }:
{
  imports = [
    ./apparmor.nix
    ./bootloader.nix
    ./hardware.nix
    ./host-cpu-packages.nix
    ./input.nix
    ./network.nix
    ./nh.nix
    ./pipewire.nix
    ./program.nix
    ./security.nix
    ./services.nix
    ./sops.nix
    ./system.nix
    ./tailscale.nix
    ./user.nix
    ./wayland.nix
  ];
}

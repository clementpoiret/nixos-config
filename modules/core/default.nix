{ ... }:
{
  imports = [
    ./bootloader.nix
    ./hardware.nix
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

{ inputs, nixpkgs, self, username, host, ... }: {
  imports = [
    ./bootloader.nix
    ./hardware.nix
    #./kanata/kanata.nix
    ./network.nix
    ./nh.nix
    ./pipewire.nix
    ./program.nix
    ./security.nix
    ./services.nix
    ./sops.nix
    ./system.nix
    ./user.nix
    ./virtualization.nix
    ./wayland.nix
    ./xserver.nix
  ];
}

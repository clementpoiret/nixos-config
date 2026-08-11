# Repository-specific hardening entrypoint for clementpoiret/nixos-config.
#
# This module assumes `host`, `username`, and `inputs` are available through
# mkHost specialArgs, as they are in the reviewed repository.

{ host, ... }:

{
  imports = [
    ./common.nix
    ./cachyos-kernel.nix
    ./secure-boot.nix
    (
      if host == "desktop" then
        ./desktop.nix
      else if host == "laptop" then
        ./laptop.nix
      else
        throw "modules/hardening: unsupported host '${host}'"
    )
  ];
}

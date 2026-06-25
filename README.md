# Clement's NixOS Configuration

Single flake-based NixOS configuration for the `desktop` and `laptop` hosts,
with Home Manager integrated into each NixOS build.

## Layout

- `flake.nix`: flake inputs, overlays, and host outputs.
- `lib/mkHost.nix`: shared host constructor.
- `hosts/<host>/`: host entrypoint, hardware config, and host facts.
- `modules/core/`: shared NixOS modules.
- `modules/home/`: Home Manager modules.
- `pkgs/`: local packages exposed through the default overlay.
- `secrets/`: sops-nix encrypted secrets.
- `nixos-guide.md`: architecture and operations guide used for the current refactor.

## Hosts

- `desktop`: desktop workstation with Nvidia-specific host configuration.
- `laptop`: Framework laptop configuration with laptop-specific power,
  hibernation, Framework, and AMD GPU quirks.

## Common Commands

```bash
# Evaluate without changing the system
nix flake check --no-update-lock-file

# Build host toplevels
nix build .#nixosConfigurations.laptop.config.system.build.toplevel
nix build .#nixosConfigurations.desktop.config.system.build.toplevel

# Test or switch the local machine
nh os test
nh os switch

# Update flake inputs
nix flake update
```

The shell aliases `nix-test`, `nix-switch`, `nix-update`, and
`nix-flake-update` wrap the same workflow.

## Secrets

Secrets are managed with `sops-nix`. Decrypted values are consumed at runtime
through `/run/secrets` for system services and Home Manager's
`~/.config/sops-nix/secrets` symlinks for user services.

Do not read decrypted secret files during Nix evaluation. Runtime writer
services generate user files such as SSH, mail, and `.pypirc` configs after
`sops-nix.service` has decrypted the relevant values.

## Notes

`pkgs.master` is intentionally exposed through the overlay as an emergency
escape hatch when a fix is available on `nixpkgs/master` but has not reached
`nixpkgs-unstable` yet.

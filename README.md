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
- `docs/`: bootstrap, operations, architecture decisions, and host notes.
- `nixos-guide.md`: architecture and operations guide used for the current refactor.

## Hosts

- `desktop`: desktop workstation with Nvidia-specific host configuration.
- `laptop`: Framework laptop configuration with laptop-specific power,
  hibernation, Framework, and AMD GPU quirks.

## Common Commands

```bash
# Enter a shell with Nix tooling
nix develop

# Format Nix files
nix fmt

# Evaluate without changing the system
nix flake check --no-update-lock-file

# Build host toplevels
nix build .#checks.x86_64-linux.laptop-toplevel
nix build .#checks.x86_64-linux.desktop-toplevel

# Test or switch the local machine
nh os test
nh os switch

# Update flake inputs
nix flake update
```

The shell aliases `nix-test`, `nix-switch`, `nix-update`, and
`nix-flake-update` wrap the same workflow.

## Documentation

- `docs/BOOTSTRAP.md`: provisioning, recovery, and secret key setup.
- `docs/OPERATIONS.md`: build, test, switch, boot, rollback, and update flows.
- `docs/DECISIONS.md`: input, Home Manager, hardware, and secrets policy.
- `docs/HOSTS.md`: host inventory and machine-specific notes.

## Secrets

Secrets are managed with `sops-nix`. Decrypted values are consumed at runtime
through `/run/secrets` for system services and Home Manager's
`~/.config/sops-nix/secrets` symlinks for user services.

Do not read decrypted secret files during Nix evaluation. Runtime writer
services generate user files such as SSH and mail configs after `sops-nix`
has decrypted the relevant values.

## Notes

Active app and tool flakes should follow the root `nixpkgs` input when that is
compatible with the upstream flake. Boot-critical or upstream-sensitive flakes
may keep their own `nixpkgs` pin to reduce upgrade risk.

`pkgs.master` is intentionally exposed through the overlay as an emergency
escape hatch when a fix is available on `nixpkgs/master` but has not reached
`nixpkgs-unstable` yet.

# Operations

## Daily Workflow

```bash
nix develop
nix fmt
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.laptop-toplevel
nix build .#checks.x86_64-linux.desktop-toplevel
```

Use `nh os test` before switching the current host:

```bash
nh os test
nh os switch
```

## Riskier Changes

Use `boot` instead of `switch` for kernel, bootloader, initrd, filesystem,
hibernation, or GPU-driver changes:

```bash
sudo nixos-rebuild boot --flake .#laptop
sudo reboot
```

Use `build-vm` when a change can be checked in a VM:

```bash
sudo nixos-rebuild build-vm --flake .#desktop
./result/bin/run-*-vm
```

## Rollback

Rollback the current system generation:

```bash
sudo nixos-rebuild switch --rollback
```

If the machine does not boot, select an older generation from the bootloader.
For bootloader repair from a live ISO, mount the system, enter it, and activate
a known-good generation:

```bash
sudo nixos-enter
NIXOS_INSTALL_BOOTLOADER=1 /run/current-system/bin/switch-to-configuration boot
```

## Input Updates

Update inputs deliberately and build both hosts before switching:

```bash
nix flake update
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.laptop-toplevel
nix build .#checks.x86_64-linux.desktop-toplevel
```

Prefer one input or one related input group per update when debugging breakage.


# Operations

## Daily Workflow

The active system continues to build from the protected `~/nixos-config` clone. Give coding agents
`~/nixos-config-writable` instead, then promote exactly one reviewed Jujutsu change:

```bash
# One-time setup, run from an unconfined terminal after protected @ is an empty change.
nixos-config-agent init

cd ~/nixos-config-writable
jj describe -m 'fix(apparmor): describe the reviewed change'

# Review the displayed full Git diff and type the full commit ID when prompted.
nixos-config-agent promote
```

`init` refuses an existing destination and clones the exact protected baseline. `promote` requires an interactive,
unconfined terminal; an empty protected working change; one non-empty, conflict-free candidate whose sole parent is that
baseline; and a Conventional Commit description. It fetches the exact candidate through a local handoff bookmark,
displays its full diff, requires the complete commit ID, and rechecks both repositories before changing the protected
clone. A rejection or stale baseline leaves the protected working tree unchanged. Success leaves an empty working
change in both clones. `nh` and the rebuild aliases intentionally continue to reference `~/nixos-config`.

The review gate becomes an AppArmor security boundary only after the relevant agent profile is enforced. In staged or
complain mode, AppArmor intentionally permits policy violations, so the separate clone is a workflow safeguard rather
than an OS-level write barrier. Do not promote an agent profile until its enforced workflow passes the documented tests.

```bash
nix develop
nix fmt
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.laptop-toplevel
nix build .#checks.x86_64-linux.desktop-toplevel
```

Use run0 elevation and test before switching the current host:

```bash
nixos-rebuild test --flake .#laptop --elevate=run0
nixos-rebuild switch --flake .#laptop --elevate=run0
```

## Riskier Changes

Use `boot` instead of `switch` for kernel, bootloader, initrd, filesystem,
hibernation, or GPU-driver changes:

```bash
nixos-rebuild boot --flake .#laptop --elevate=run0
run0 -- reboot
```

Use `build-vm` when a change can be checked in a VM:

```bash
nixos-rebuild build-vm --flake .#desktop
./result/bin/run-*-vm
```

## Rollback

Rollback the current system generation:

```bash
nixos-rebuild switch --rollback --elevate=run0
```

If the machine does not boot, select an older generation from the bootloader.
For bootloader repair from a live ISO, mount the system, enter it, and activate
a known-good generation:

```bash
# The stock live installer has sudo; the installed system's run0 policy is not
# active until after entering it.
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

## Continuous Integration and Cachix

The GitHub Actions workflow builds every flake check on pushes to `main`. Every
Sunday it updates Herdr and Superfile to their latest stable release tags,
updates all flake inputs, builds the updated checks, and pushes the verified
`flake.nix` and `flake.lock` directly to `main`.

Configure a repository Actions secret named `CACHIX_AUTH_TOKEN` with a
cache-scoped write token for the `clementpoiret` Cachix cache. The workflow
fails before building if this secret is unavailable. Existing paths are pulled
from configured binary caches; only newly built paths are uploaded to Cachix.

## Hardening changes

Follow [HARDENING.md](HARDENING.md) for boot-first deployment, the recovery
specialisation, runtime checks, and optional strict controls. USBGuard has a
separate cold-boot rollout in [USBGUARD.md](USBGUARD.md). Laptop Secure Boot,
measured boot, TPM enrollment, firmware updates, and motherboard replacement
are covered by [MEASURED-BOOT.md](MEASURED-BOOT.md).

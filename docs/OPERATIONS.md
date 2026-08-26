# Operations

## Daily Workflow

The active system continues to build from the protected `~/nixos-config` clone. Give coding agents
`~/nixos-config-writable` instead, then promote exactly one reviewed Jujutsu change. The protected
clone's `origin` must point to GitHub:

```bash
# One-time setup, run from an unconfined terminal after protected @ is an empty change.
nixos-config-agent init

# Refresh GitHub main, advance local main, and rebase local work when fast-forwardable.
nixos-config-agent fetch

cd ~/nixos-config-writable
jj describe -m 'fix(apparmor): describe the reviewed change'

# Review the syntax-highlighted Delta diff and type the full commit ID when prompted.
nixos-config-agent promote

# After all intended changes are promoted, review, sign, and publish protected main.
nixos-config-agent push
```

`init` refuses an existing destination and clones the exact protected baseline. `promote` requires an interactive,
unconfined terminal; an empty protected working change; one non-empty, conflict-free candidate whose sole parent is that
baseline; and a Conventional Commit description. It fetches the exact candidate through a local handoff bookmark,
displays its full Git diff through the configured Jujutsu pager (Delta), requires the complete commit ID, and rechecks
both repositories before changing the protected clone. A rejection or stale baseline leaves the protected working tree
unchanged. Success leaves an empty working change in both clones.

`fetch` mirrors the protected clone's `origin` URL into the writable clone as `github`, then fetches `origin/main` in
the protected clone and `github/main` in the writable clone. When GitHub is a fast-forward of protected `main`, it
advances local `main`, rebases any promoted protected revisions, and rebases an active or empty writable change onto
the exact rewritten protected baseline. If either rebase conflicts, both clones are restored while the fetched GitHub
metadata is retained. A locally-ahead `main` is left unchanged, and genuinely divergent history must be reconciled
explicitly before publishing.

`push` is an interactive, unconfined post-promotion operation. It refuses an active writable change, conflicts,
divergent history, or any unpublished revision without a Conventional Commit subject. It signs only unsigned revisions
between `main@origin` and the protected baseline, shows the complete revision list and cumulative Delta diff, advances
local `main`, and runs an exact-bookmark dry run. The final prompt requires the full post-signing commit ID. A rejection
or pre-push failure leaves GitHub unchanged, restores local `main`, and realigns the empty writable clone if signing
rewrote commit IDs. After a successful GitHub push, it fetches `github/main`, rebases the writable empty change onto the
published revision, and advances `agent-base` and `agent-handoff`. A failure during this last synchronization is reported
as a partial success and does not roll back GitHub.

`nh` and the rebuild aliases intentionally continue to reference `~/nixos-config`.

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
cache-scoped write token for the private `clementpoiret` Cachix cache. The
workflow fails before building if this secret is unavailable. Keep the cache
private because the curated host outputs include the non-redistributable
VirtualBox Extension Pack. Existing paths are pulled from configured binary
caches; newly built curated outputs are uploaded and the current optimized
roots are pinned in Cachix. Complete host configurations are built for
validation without being watched or pinned by Cachix.

## Hardening changes

Follow [HARDENING.md](HARDENING.md) for boot-first deployment, the recovery
specialisation, runtime checks, and optional strict controls. USBGuard has a
separate cold-boot rollout in [USBGUARD.md](USBGUARD.md). Laptop Secure Boot,
measured boot, TPM enrollment, firmware updates, and motherboard replacement
are covered by [MEASURED-BOOT.md](MEASURED-BOOT.md).

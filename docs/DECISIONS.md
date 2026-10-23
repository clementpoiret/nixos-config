# Decisions

## Flake Shape

The flake delegates host construction to `lib/mkHost.nix` and check definitions,
including AppArmor test host variants, to `tests/flake-checks.nix`.
Both hosts are `x86_64-linux`, so there is no `flake-parts` or broad
multi-system abstraction yet.

## Inputs

The root system package set follows `nixos-unstable`. App and tool flakes follow
that same input, including Niri's package-set inputs; its source remains pinned
independently. Niri's required libdisplay-info 0.2 ABI is packaged locally with
the host toolchain rather than imported from stable.

`nixpkgs-stable` and `nixpkgs-master` remain exposed as `pkgs.stable` and
`pkgs.master` for explicit per-package fallbacks. Neither is used by default.
For a flake-packaged application, switch its `inputs.nixpkgs.follows` to
`nixpkgs-stable` or `nixpkgs-master` instead; keep any exact-path AppArmor helper
registrations aligned with the application's package set.

CachyOS retains its own pinned nixpkgs input and `overlays.pinned` to preserve
the kernel derivations published by its binary cache. Do not make it follow
the root package set.

## Home Manager

Home Manager is integrated as a NixOS module. `useGlobalPkgs = true` keeps Home
Manager on the same package set and overlays as the system.

Standalone Home Manager flake outputs are intentionally not exposed.

## Verification

Keep checks for runtime compatibility, confinement boundaries, authenticated
updates, boot retention, and preservation of user work. Use the real parser,
binaries, or isolated integration fixtures where possible. Avoid duplicating
configuration literals, release manifests, cosmetic preferences, or retired
implementation details in tests. Package/profile alignment is checked for every
enabled application instead of maintaining per-application snapshots.

## Hardware

Generated `hardware-configuration.nix` files stay in host directories and
should remain mostly generated hardware facts.

Host facts declare CPU targets and kernel tick/lazy-RCU tuning. Shared modules
consume these values directly, so adding a host does not require hostname
dispatch in the CPU or kernel modules. Fan control, ambient-light settings, and
location policy belong in the host entrypoint.

The Framework laptop imports `nixos-hardware.nixosModules.framework-16-7040-amd`
for upstream model defaults. Host-local laptop settings should be limited to
local policy, hibernation values, and quirks not covered upstream.

## Secrets

Secrets are managed with `sops-nix`. Cleartext secrets must not enter the Nix
store. Use runtime secret paths from `config.sops.secrets.*.path`.

## Operations

`.github/workflows/nix-cache.yml` builds and caches the configurations on pushes
to `main`, weekly schedules, and manual dispatch. Scheduled and manual runs also
update pinned releases and the lockfile. Local checks remain available through
the flake's `checks.x86_64-linux` outputs.

## Hardening ownership

Security policy is not kept in a separate catch-all module. Each active option
lives with its subsystem: boot-chain, hardware/kernel, local security, network,
services, Nix daemon, or host-specific policy. This avoids priority overrides
that merely cancel a permissive value defined elsewhere.

Compatibility-sensitive controls remain explicit host decisions. Development
hardware access is retained as a feature, USBGuard stays disabled until a
reviewed laptop policy exists, and high-breakage strict controls are commented
beside their owners for one-at-a-time trials.

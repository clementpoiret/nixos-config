# Decisions

## Flake Shape

The flake stays small and delegates host construction to `lib/mkHost.nix`.
Both hosts are `x86_64-linux`, so there is no `flake-parts` or broad
multi-system abstraction yet.

## Inputs

The root system package set follows `nixpkgs-unstable`.

`nixpkgs-stable` is kept for selected tools that are safer or more reliable on
a stable branch.

`nixpkgs-master` is intentionally exposed as `pkgs.master`. Keep it available
as an explicit emergency escape hatch when a fix exists on master but has not
reached unstable.

Most app and tool flakes should follow the root `nixpkgs` input. Exceptions are
allowed for boot-critical or upstream-sensitive flakes where keeping an upstream
pin reduces upgrade risk.

## Home Manager

Home Manager is integrated as a NixOS module. `useGlobalPkgs = true` keeps Home
Manager on the same package set and overlays as the system.

Standalone Home Manager flake outputs are intentionally not exposed.

## Hardware

Generated `hardware-configuration.nix` files stay in host directories and
should remain mostly generated hardware facts.

The Framework laptop imports `nixos-hardware.nixosModules.framework-16-7040-amd`
for upstream model defaults. Host-local laptop settings should be limited to
local policy, hibernation values, and quirks not covered upstream.

## Secrets

Secrets are managed with `sops-nix`. Cleartext secrets must not enter the Nix
store. Use runtime secret paths from `config.sops.secrets.*.path`.

## Operations

This repo is local-first for now. CI and cache publishing are intentionally left
out until they are needed.


# Kernel configuration

Both hosts use `linuxPackages-cachyos-latest-lto-zen4` from
`github:clementpoiret/nix-cachyos-kernel/release`. Keep the flake's own nixpkgs
input and `overlays.pinned`: the release branch and unmodified preset match
the kernels published to `https://nixos-cachyos-kernels.cachix.org`.
The package set includes LLVM and VirtualBox module build fixes and applies the
`kernelModuleSignOverride` helper. It signs external modules such as `acpi_call`
and `framework_laptop` after stripping when their installers skip Kbuild's
signing step, producing the `.ko.cer` certificates Nixpkgs' module-tree
aggregator needs. Do not duplicate these signing overrides locally.

## Differences from the custom kernel

| Setting | Previous custom kernel | Cached preset |
| --- | --- | --- |
| Compiler / CPU | Clang ThinLTO / Zen 4 | Same |
| KCFI request | `true` (ineffective; see below) | `false` |
| Timer frequency | Laptop: 300 Hz; desktop: 500 Hz | 1000 Hz on both |
| Tickless mode | `idle` (`NO_HZ_IDLE`) | `full` (`NO_HZ_FULL`) |
| Transparent huge pages | `madvise` by default | `always` by default |

Full tickless support does not by itself isolate CPUs or enable `nohz_full`
on them. The existing `transparent_hugepage=madvise` boot parameter preserves
the runtime huge-page policy despite the preset's compiled default.
EEVDF, full dynamic preemption, harder compiler optimizations, no forced
performance governor, `bbr3 = false`, and automatic module selection are
unchanged. SCX/LAVD remains enabled separately and supersedes EEVDF while
the SCX scheduler is active.

The previous laptop kernel's generated config and the cached preset both
have `CONFIG_CFI` disabled. The flake's `kcfi` helper still sets the old
`CFI_CLANG` symbols, while these kernel versions use `CONFIG_CFI`; requesting
`kcfi = true` did not enable it. Restoring the old recipe alone does not
restore CFI protection: verify the generated config, not just that argument.

The cache URL and signing key are configured in `modules/core/system.nix`.
They must be active in the Nix daemon before it can substitute from the new
cache; merely editing the configuration does not update the running daemon.
For the first build, root can supply them explicitly (replace `laptop` with
`desktop` for that host):

```bash
run0 -- nix build --no-link --no-update-lock-file \
  --extra-substituters https://nixos-cachyos-kernels.cachix.org \
  --extra-trusted-public-keys 'nixos-cachyos-kernels.cachix.org-1:ccFqQ2GZOeTAPrZaDDsCY5Rk1Ndg/+NnM2s6UwIDTS0=' \
  .#checks.x86_64-linux.laptop-toplevel
```

Then install a boot generation following
[HARDENING.md](HARDENING.md#deployment-and-recovery), without switching the
running kernel.

## Restore the custom kernel

In `modules/core/hardware.nix`, insert this `let` block between the module
arguments (`}:`) and its returned attribute set (`{`), then replace
`boot.kernelPackages` with
`cachyosHelpers.kernelModuleSignOverride customKernelPackages`. The per-host
timer values remain in `hosts/laptop/facts.nix` and `hosts/desktop/facts.nix`.

```nix
let
  baseKernel = pkgs.cachyosKernels.linux-cachyos-latest;
  customKernel = baseKernel.override {
    lto = "thin";
    processorOpt = "zen4";

    cpusched = "eevdf";
    kcfi = true;
    hzTicks = hostFacts.hardware.kernel.hzTicks;
    performanceGovernor = false;
    tickrate = "idle";
    preemptType = "full";
    ccHarder = true;
    bbr3 = false;
    hugepage = "madvise";
    autoModules = true;
  };

  cachyosHelpers = pkgs.callPackage "${inputs.nix-cachyos-kernel.outPath}/helpers.nix" { };
  customKernelPackages =
    let
      kernelPackages = cachyosHelpers.kernelModuleLLVMOverride (
        pkgs.linuxKernel.packagesFor customKernel
      );
    in
    kernelPackages.extend (
      _final: prev: {
        # VirtualBox does not inherit the custom kernel's LLVM build flags.
        virtualbox = prev.virtualbox.overrideAttrs (oldAttrs: {
          makeFlags = (oldAttrs.makeFlags or [ ]) ++ kernelPackages.kernel.commonMakeFlags;
        });
      }
    );
in
```

Restoring these overrides requires a custom kernel build. Update the
`cached-kernel` check in `tests/flake-checks.nix` to check the restored policy
rather than equality with the cached preset, and update the active baseline in
`HARDENING.md`.
Keep the `kernelModuleSignOverride` wrapper: a custom kernel build does not
repair package installers that skip Kbuild's signing step.

# Hosts

## desktop

Desktop workstation with an MSI MAG X870E Tomahawk WiFi motherboard, Ryzen 9
9950X3D, AMD integrated graphics, and an RTX 4080 reserved for CUDA/AI workloads.

Local host policy includes:

- CachyOS latest LTO Zen4 kernel with 500 Hz tuning and AMD P-State active mode.
- `facts.nix` selects `znver5` for host-optimized applications and leaves lazy RCU
  at its kernel default.
- Power Profiles Daemon defaults to Balanced, while LAVD Autopilot remains the
  interactive sched-ext policy.
- The frequency CCD is preferred through the kernel's `amd_x3d_mode` interface.
- Encrypted Btrfs filesystems with Zstd level 3 compression and asynchronous
  discard.
- AMD integrated graphics for Niri and the stable Nvidia driver for compute.
- Niri is pinned to the AMD render device; Nvidia PRIME/offload is disabled.
- LACT is enabled for staged RTX 4080 power-limit profiles; no power cap or
  persistence mode is imposed at boot.
- RAS logging and CPU, GPU, memory, and stress-test tooling are installed for
  stability validation.
- The ucodenix SHA-check bypass is disabled; verify the loaded microcode
  revision and kernel log after firmware, kernel, or ucodenix updates.
- Running-kernel image protection is enabled; hibernation is intentionally
  unavailable.
- Integrity Lockdown and module enforcement remain optional trials gated on
  NVIDIA signer and recovery validation.

Keep the integrated GPU enabled in UEFI when the RTX 4080 is installed. Connect
monitors to the motherboard HDMI or USB-C DisplayPort outputs so that the RTX
4080 is not involved in desktop rendering.

Build target:

```bash
nix build .#checks.x86_64-linux.desktop-toplevel
```

After testing a new generation on the desktop, verify the policy and services:

```bash
powerprofilesctl get
cat /sys/devices/system/cpu/amd_pstate/status
cat /sys/devices/system/cpu/amd_pstate/prefcore
cat /sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode
systemctl is-active scx lactd rasdaemon \
  desktop-power-profile-balanced desktop-x3d-frequency
cat /sys/kernel/sched_ext/state
cat /sys/kernel/sched_ext/root/ops
nvidia-smi
lact cli list-gpus
systemctl --failed
```

Create and validate `4080_STOCK`, `4080_TRAIN_SAFE_280W`,
`4080_TRAIN_EFFICIENT_270W`, and `4080_INFER_250W` in LACT. Keep clocks, VRAM,
and fans at stock settings, and keep the stock profile active until each power
cap has passed its representative workload. Do not persist `nct6683 force=1`
until it has been tested directly on the desktop.

The shared `/tmp` is a tmpfs limited to 50% of RAM. Keep unbounded build trees,
AI datasets, checkpoints, and other large scratch data on persistent NVMe
storage instead.

## laptop

Framework Laptop 16 AMD 7040 configuration.

The host imports `nixos-hardware.nixosModules.framework-16-7040-amd` for common
Framework defaults, including firmware update support, Framework tooling,
keyboard/module access rules, AMD common defaults, and power profile defaults.

Local host policy includes:

- CachyOS latest LTO Zen4 kernel with laptop-specific 300 Hz and lazy RCU tuning.
- `facts.nix` selects `znver4` for host-optimized applications and records kernel tuning.
- Fan control, ambient-light adjustment, and city-level location policy live in `default.nix`.
- LAVD Autopower follows the active platform power profile when selecting its
  power mode, CPU preference order, and core-compaction policy.
- Hibernation resume device and swapfile offset.
- AMD dGPU/iGPU stable DRM symlinks.
- ROCm runtime, OpenCL, and ML-training support in `hosts/laptop/rocm.nix`.
- Ghostty shaders render only on terminal updates; desktop shaders animate only
  while focused.
- TRIM passes through both LUKS mappings to the SSDs. This exposes block
  allocation patterns on the encrypted devices.
- Panel self-refresh is allowed by filtering the inherited
  `amdgpu.dcdebugmask=0x10` workaround out of the kernel parameters.
- The ucodenix SHA-check bypass is disabled; verify the loaded microcode
  revision and kernel log after firmware, kernel, or ucodenix updates.
- Local power-button and lid behavior.
- Local `ananicy-cpp` policy.
- Kexec is disabled while encrypted hibernation remains available. Linux
  Lockdown must remain disabled while hibernation is required.
- USBGuard remains deferred to the reviewed rollout in `docs/USBGUARD.md`.

Build target:

```bash
nix build .#checks.x86_64-linux.laptop-toplevel
```

Apply the TRIM and panel self-refresh changes using the `boot` workflow in
`OPERATIONS.md`, then reboot. Check that `/proc/cmdline` no longer contains
`amdgpu.dcdebugmask=0x10` and that `lsblk -D` reports a nonzero `DISC-MAX` for
both LUKS mappings. Test static screen content, video, and suspend/resume on
both AC and battery power. Removing the override permits the driver's default
PSR behavior; it does not prove the panel enters PSR or establish battery savings.
If display hangs return, boot the previous generation and remove the
`boot.kernelParams` filter in `hosts/laptop/default.nix` to restore the upstream
workaround.

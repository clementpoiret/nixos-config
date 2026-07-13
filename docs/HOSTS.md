# Hosts

## desktop

Desktop workstation with an MSI MAG X870E Tomahawk WiFi motherboard, Ryzen 9
9950X3D, AMD integrated graphics, and an RTX 4080 reserved for CUDA/AI workloads.

Local host policy includes:

- Performance CPU governor.
- CachyOS latest LTO Zen4 kernel and AMD P-State active mode.
- Encrypted Btrfs filesystems with Zstd level 3 compression and asynchronous
  discard.
- AMD integrated graphics for Niri and the stable Nvidia driver for compute.
- Niri is pinned to the AMD render device; Nvidia PRIME/offload is disabled.
- AMD microcode loading workaround for `ucodenix`.

Keep the integrated GPU enabled in UEFI when the RTX 4080 is installed. Connect
monitors to the motherboard HDMI or USB-C DisplayPort outputs so that the RTX
4080 is not involved in desktop rendering.

Build target:

```bash
nix build .#checks.x86_64-linux.desktop-toplevel
```

## laptop

Framework Laptop 16 AMD 7040 configuration.

The host imports `nixos-hardware.nixosModules.framework-16-7040-amd` for common
Framework defaults, including firmware update support, Framework tooling,
keyboard/module access rules, AMD common defaults, and power profile defaults.

Local host policy includes:

- Hibernation resume device and swapfile offset.
- AMD dGPU/iGPU stable DRM symlinks.
- ROCm runtime, OpenCL, and ML-training support in `hosts/laptop/rocm.nix`.
- `amdgpu.sg_display=0`.
- AMD microcode loading workaround for `ucodenix`.
- Local power-button and lid behavior.
- Local `ananicy-cpp` policy.

Build target:

```bash
nix build .#checks.x86_64-linux.laptop-toplevel
```

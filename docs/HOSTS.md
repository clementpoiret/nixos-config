# Hosts

## desktop

Desktop workstation with Nvidia-specific configuration.

Local host policy includes:

- Performance CPU governor.
- Nvidia beta driver package.
- Nvidia Wayland environment variables.
- AMD microcode loading workaround for `ucodenix`.

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

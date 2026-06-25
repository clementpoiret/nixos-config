# ROCm ML Training

The Framework Laptop 16 has two ROCm-visible AMD GPUs:

- dGPU: Radeon RX 7700S, `gfx1102`, 8 GB VRAM.
- iGPU: Radeon 780M, `gfx1103`, shared memory.

Use the dGPU for training. The `ml-rocm` development shell selects device `0`
by default through `ROCR_VISIBLE_DEVICES`, `HIP_VISIBLE_DEVICES`, and
`GPU_DEVICE_ORDINAL`.

## Enter the environment

```bash
nix develop .#ml-rocm
```

This shell intentionally does not package PyTorch or JAX through Nix. It
provides Python 3.12, `uv`, ROCm diagnostics, dGPU selection, and the system
library path needed by common manylinux wheels on NixOS.

The JAX ROCm plugin needs local ROCm shared libraries. `.#ml-rocm` provides
those from the `nixpkgs-stable` ROCm package set because stable `miopen-7.2.3`
is available from `cache.nixos.org`; the matching unstable/master MIOpen output
was not cached for this flake revision. The first shell entry may therefore
download a large cached ROCm runtime closure, but it should not compile MIOpen
locally.

## Validate ROCm

```bash
rocminfo | rg 'gfx1102|RX 7700S|KERNEL_DISPATCH'
rocm-smi --showbus --showproductname
clinfo | rg 'Device Name|Device Version|OpenCL'
```

## Temporary uv environment

```bash
tmp="$(mktemp -d)"
cd "$tmp"

uv venv --python python3.12
uv pip install torch torchvision --index-url "$PYTORCH_ROCM_INDEX_URL"

. .venv/bin/activate
```

For a reusable project, start from `templates/ml-rocm-uv/pyproject.toml` instead
of installing packages manually.

## PyTorch

```bash
python - <<'PY'
import torch

print("HIP:", torch.version.hip)
print("available:", torch.cuda.is_available())

props = torch.cuda.get_device_properties(0)
print("device:", props.name)
print("gcnArchName:", getattr(props, "gcnArchName", None))
print("total_memory_gib:", round(props.total_memory / 1024**3, 2))

x = torch.randn((4096, 4096), device="cuda")
print((x @ x).mean().item())
PY
```

The tested wheel set was:

- `torch==2.12.1+rocm7.2`
- `torchvision==0.27.1+rocm7.2`
- `triton-rocm==3.7.1`

PyTorch reported the dGPU as `gfx1102` with about 8 GiB VRAM.

## JAX

Install JAX from the official ROCm local extra:

```bash
uv pip install --upgrade "jax[rocm7-local]"
```

The JAX plugin still rejects native `gfx1102`, so scope the gfx override to JAX
commands:

```bash
export HSA_OVERRIDE_GFX_VERSION=11.0.0
```

Validate JAX:

```bash
python /home/clementpoiret/nixos-config/templates/ml-rocm-uv/jax-smoke.py
```

The tested JAX stack was:

- `jax==0.10.2`
- `jaxlib==0.10.2`
- `jax-rocm7-pjrt==0.10.2`
- `jax-rocm7-plugin==0.10.2`

It reported `backend: gpu`, `devices: [RocmDevice(id=0)]`, and completed a
1024x1024 matrix multiply on the dGPU.

Keep `HSA_OVERRIDE_GFX_VERSION=11.0.0` scoped to JAX commands unless another
framework explicitly needs it. The ROCm runtime and PyTorch both detect the
dGPU as `gfx1102` directly.

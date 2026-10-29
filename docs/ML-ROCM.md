# ROCm ML Training

The Framework Laptop 16 has two ROCm-visible AMD GPUs:

- dGPU: Radeon RX 7700S, `gfx1102`, 8 GB VRAM.
- iGPU: Radeon 780M, `gfx1103`, shared memory.

Use the dGPU for training. The `ml-rocm` development shell selects device `0`
by default through `ROCR_VISIBLE_DEVICES`, `HIP_VISIBLE_DEVICES`, and
`GPU_DEVICE_ORDINAL`.

## Enter the environment

Run these commands from the repository root:

```bash
nix develop .#ml-rocm
```

This shell intentionally does not package PyTorch or JAX through Nix. It
provides Python 3.12, `uv`, ROCm diagnostics, dGPU selection, and the system
library path needed by common manylinux wheels on NixOS.

The JAX ROCm plugin needs local ROCm shared libraries. `.#ml-rocm` provides
those from the same `nixos-unstable` package set as its diagnostics. The first
shell entry can download a large ROCm runtime closure. Check substitution
availability before updating: a missing MIOpen cache entry can require an
expensive local build. Revalidate the GPU workloads below after changing the
ROCm package set; the recorded wheel tests predate this package-set migration.

```bash
nix build --dry-run --no-link --no-update-lock-file .#devShells.x86_64-linux.ml-rocm
```

## Validate ROCm

```bash
rocminfo | rg 'gfx1102|RX 7700S|KERNEL_DISPATCH'
rocm-smi --showbus --showproductname
clinfo | rg 'Device Name|Device Version|OpenCL'
```

## Temporary uv environment

Use persistent storage: `/tmp` is RAM-backed, and GPU wheels and their unpacked
environments can consume several GiB. Check available space before installing.

```bash
repo_root="$PWD"
scratch_root="$HOME/.cache/ml-rocm"
df -h "$HOME"
mkdir -p "$scratch_root"
scratch_dir="$(mktemp -d "$scratch_root/session.XXXXXXXX")"
cd "$scratch_dir"

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

Earlier wheel validation used:

- `torch==2.12.1+rocm7.2`
- `torchvision==0.27.1+rocm7.2`
- `triton-rocm==3.7.1`

PyTorch reported the dGPU as `gfx1102` with about 8 GiB VRAM.

## JAX

Install JAX from the official ROCm local extra:

```bash
uv pip install --upgrade "jax[rocm7-local]"
```

The recorded JAX stack rejects native `gfx1102`. Scope its gfx override to the
validation command:

```bash
HSA_OVERRIDE_GFX_VERSION=11.0.0 python "$repo_root/templates/ml-rocm-uv/jax-smoke.py"
```

Earlier JAX validation used:

- `jax==0.10.2`
- `jaxlib==0.10.2`
- `jax-rocm7-pjrt==0.10.2`
- `jax-rocm7-plugin==0.10.2`

It reported `backend: gpu`, `devices: [RocmDevice(id=0)]`, and completed a
1024x1024 matrix multiply on the dGPU.

Do not export the override for the whole shell: the ROCm runtime and PyTorch
detect the dGPU as `gfx1102` directly.

## Clean up

After testing, remove only the scratch environment created above:

```bash
deactivate
cd "$repo_root"
rm -r -- "$scratch_dir"
```

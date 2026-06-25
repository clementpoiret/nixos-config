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

This shell intentionally does not package PyTorch through Nix. It provides
Python 3.12, `uv`, ROCm diagnostics, dGPU selection, and the system library path
needed by common manylinux wheels on NixOS. Install PyTorch from the official
ROCm wheel index inside a project or temporary virtual environment.

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

ROCm JAX is less clean on this laptop. The `ROCm/rocm-jax` repository is
deprecated for wheel development, but its `rocm-jax-v0.9.1` release still
publishes usable wheelhouses. The release wheels do not include every ROCm
shared library they link against, and the plugin rejects native `gfx1102`, so
the tested path uses the ROCm libraries bundled in the PyTorch wheel plus
`HSA_OVERRIDE_GFX_VERSION=11.0.0`.

The missing JAX runtime libraries are normal ROCm libraries:

- `libMIOpen.so.1`
- `libhipblaslt.so.1`
- `libhipfft.so.0`
- `librccl.so.1`
- `libroctracer64.so.4`
- `librocm_smi64.so.1`
- `librocprofiler-sdk.so.1`

They can come from Nixpkgs ROCm packages, but doing that in `.#ml-rocm` can
force large local ROCm builds, especially `miopen`. For that reason the default
documented path reuses the already-downloaded PyTorch ROCm wheel libraries.
`flake.nix` contains a commented `jaxNixRocmLibs` block inside the `ml-rocm`
shell if you want to opt into Nix-provided ROCm libraries later.

Install JAX into the same uv environment as PyTorch:

```bash
curl -L --fail --show-error --remote-name "$ROCM_JAX_WHEELHOUSE_URL"
unzip -q "$(basename "$ROCM_JAX_WHEELHOUSE_URL")"

uv pip install \
  jax==0.9.1 \
  wheelhouse_post5_generic_archs_theRock7.12/jax_rocm7_pjrt-0.9.1.post5-py3-none-manylinux_2_28_x86_64.whl \
  wheelhouse_post5_generic_archs_theRock7.12/jax_rocm7_plugin-0.9.1.post5-cp312-cp312-manylinux_2_28_x86_64.whl
```

Prepare the compatibility library path:

```bash
export LD_LIBRARY_PATH="$(
  bash /home/clementpoiret/nixos-config/templates/ml-rocm-uv/prepare-jax-rocm-libs.sh
):$LD_LIBRARY_PATH"
export HSA_OVERRIDE_GFX_VERSION=11.0.0
```

Validate JAX:

```bash
python /home/clementpoiret/nixos-config/templates/ml-rocm-uv/jax-smoke.py
```

The tested JAX stack was:

- `jax==0.9.1`
- `jaxlib==0.9.1`
- `jax-rocm7-pjrt==0.9.1.post5`
- `jax-rocm7-plugin==0.9.1.post5`

It reported `backend: gpu`, `devices: [RocmDevice(id=0)]`, and completed a
1024x1024 matrix multiply on the dGPU.

Keep `HSA_OVERRIDE_GFX_VERSION=11.0.0` scoped to JAX commands unless another
framework explicitly needs it. The ROCm runtime and PyTorch both detect the dGPU
as `gfx1102` directly.

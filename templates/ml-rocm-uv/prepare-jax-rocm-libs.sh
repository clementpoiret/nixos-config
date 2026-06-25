#!/usr/bin/env bash
set -euo pipefail

compat_dir="${1:-.rocm-jax-libs}"

torch_lib="$(
  python - <<'PY'
from pathlib import Path
import torch

print(Path(torch.__file__).resolve().parent / "lib")
PY
)"

mkdir -p "$compat_dir"

ln -sfn "$torch_lib/libMIOpen.so" "$compat_dir/libMIOpen.so.1"
ln -sfn "$torch_lib/libhipblaslt.so" "$compat_dir/libhipblaslt.so.1"
ln -sfn "$torch_lib/libhipfft.so" "$compat_dir/libhipfft.so.0"
ln -sfn "$torch_lib/librccl.so" "$compat_dir/librccl.so.1"
ln -sfn "$torch_lib/libroctracer64.so" "$compat_dir/libroctracer64.so.4"

printf '%s\n' "$PWD/$compat_dir:$torch_lib"

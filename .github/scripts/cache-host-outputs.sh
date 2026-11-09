#!/usr/bin/env bash
set -euo pipefail

host="$1"
manifest="$(
  nix eval --no-update-lock-file --json ".#cache-root-$host" \
    --apply 'root: { root = toString root; paths = map toString root.cachePaths; }'
)"
root="$(jq -er '.root' <<<"$manifest")"
mapfile -t candidates < <(jq -r '.paths[]' <<<"$manifest")

# A failed package must not prevent caching other completed, explicitly selected outputs.
paths=()
for path in "${candidates[@]}" "$root"; do
  if [[ -e "$path" ]]; then
    paths+=("$path")
  fi
done
if [[ ${#paths[@]} -eq 0 ]]; then
  echo "No selected host outputs completed"
  exit 0
fi

closure="$(nix path-info --recursive "${paths[@]}")"
kernel_outputs="$(
  nix eval --no-update-lock-file --json ".#nixosConfigurations.$host.config.boot.kernelPackages.kernel" \
    --apply 'kernel: map (output: toString (builtins.getAttr output kernel)) kernel.outputs' \
    | jq -er '.[]'
)"
if grep -Fxf <(printf '%s\n' "$kernel_outputs") <<<"$closure"; then
  echo "Kernel outputs belong in nixos-cachyos-kernels, not clementpoiret" >&2
  exit 1
fi

cachix push clementpoiret "${paths[@]}"
if [[ -e "$root" ]]; then
  cachix pin clementpoiret "host-optimized-$host" "$root" --keep-revisions 1
fi

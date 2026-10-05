"""Exercise historical specialisation cleanup on a temporary ESP, without a TPM."""

import json
import pathlib
import shutil
import subprocess
import sys
import tempfile


installer, systemd, fixtures = sys.argv[1:]
with tempfile.TemporaryDirectory() as temporary:
    root = pathlib.Path(temporary)
    esp = root / "esp"
    esp.mkdir()
    pcrlock = root / "pcrlock"
    measurements = pcrlock / "635-lanzaboote.pcrlock.d"
    measurements.mkdir(parents=True)
    (measurements / "1-latest-nixos.pcrlock").write_text("{}")
    images = esp / "EFI/Linux"
    images.mkdir(parents=True)
    (images / "nixos-generation-1-specialisation-latest-nixos-obsolete.efi").touch()

    payload = root / "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-6.1.1"
    payload.mkdir()
    stub = pathlib.Path(systemd) / "lib/systemd/boot/efi/linuxx64.efi.stub"
    for name in ("kernel", "initrd"):
        shutil.copyfile(stub, payload / name)
    loader_config = root / "loader.conf"
    loader_config.write_text("timeout 0\n")

    generations = []
    for version in range(1, 6):
        generation = root / f"system-{version}-link"
        generation.mkdir()
        (generation / "nixos-version").write_text("test")
        (generation / "kernel-modules/lib/modules/6.1.1").mkdir(parents=True)
        base = {
            "org.nixos.bootspec.v1": {
                "init": f"/init-{version}",
                "initrd": str(payload / "initrd"),
                "kernel": str(payload / "kernel"),
                "kernelParams": [],
                "label": f"Generation {version}",
                "toplevel": str(generation),
                "system": "x86_64-linux",
            },
            "org.nix-community.lanzaboote": {"sort_key": "lanzaboote"},
        }
        # Older retained generations keep their immutable specialisation metadata.
        specialisations = {"latest-nixos": base} if version < 5 else {}
        (generation / "boot.json").write_text(json.dumps({
            **base,
            "org.nixos.specialisation.v1": specialisations,
        }))
        generations.append(str(generation))

    subprocess.run([
        installer, "install", "--system", "x86_64-linux",
        "--systemd", systemd, "--systemd-boot-loader-config", str(loader_config),
        "--configuration-limit", "4", "--protected-system", generations[0],
        "--public-key", f"{fixtures}/db.pem", "--private-key", f"{fixtures}/db.key",
        "--pcrlock-directory", str(pcrlock), str(esp), *generations,
    ], check=True)

    installed_images = list(images.glob("nixos-*.efi"))
    assert len(installed_images) == 4, installed_images
    assert not any("specialisation" in image.name for image in installed_images)
    assert {path.stem for path in measurements.glob("*.pcrlock")} == {"1", "3", "4", "5"}
    assert not any(image.name.startswith("nixos-generation-2-") for image in installed_images)

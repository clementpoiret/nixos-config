#!/usr/bin/env python3
"""Pin Proton binaries to their latest official stable and supported beta releases."""

import base64
import hashlib
import json
from pathlib import Path
import re
import tempfile
from urllib.request import urlopen

from verify_signature import verify_signature


PACKAGES = {
    "proton-pass": (
        "https://proton.me/download/PassDesktop/linux/x64/version.json",
        "https://proton.me/download/pass/linux/proton-pass_{version}_amd64.deb",
    ),
    "protonmail-desktop": (
        "https://proton.me/download/mail/linux/version.json",
        "https://proton.me/download/mail/linux/{version}/ProtonMail-desktop-beta.deb",
    ),
    "protonmail-bridge": (
        "https://proton.me/download/bridge/linux/x86/v1/version.json",
        "https://proton.me/download/bridge/protonmail-bridge_{version}-1_amd64.deb",
    ),
    "proton-pass-cli": (
        "https://proton.me/download/pass-cli/versions.json",
        "https://proton.me/download/pass-cli/{version}/pass-cli-linux-x86_64",
    ),
}
BETA_CATEGORIES = {
    "proton-pass": "Beta",
    "protonmail-desktop": "EarlyAccess",
}
VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")
VERSION_DECLARATION = re.compile(r'^  version = "([^"]+)";$', re.MULTILINE)
HASH_DECLARATION = re.compile(r'^    hash = "([^"]+)";$', re.MULTILINE)
SIGNATURE_DECLARATION = re.compile(r'^  signatureHash = "([^"]+)";$', re.MULTILINE)


def verify_bridge_feed(payload, signature, key):
    with tempfile.TemporaryDirectory(prefix="bridge-release-") as directory:
        feed_path = Path(directory) / "version.json"
        signature_path = Path(directory) / "version.json.sig"
        feed_path.write_bytes(payload)
        signature_path.write_bytes(signature)
        verify_signature(key, signature_path, feed_path)


def version_key(version):
    if not isinstance(version, str) or not VERSION.fullmatch(version):
        raise ValueError(f"Invalid release version: {version!r}")
    return tuple(map(int, version.split(".")))


def release_source(package, feed, channel="stable"):
    if channel not in ("stable", "beta") or (channel == "beta" and package not in BETA_CATEGORIES):
        raise ValueError(f"Unsupported release channel for {package}: {channel}")
    _, template = PACKAGES[package]
    if package == "proton-pass-cli":
        release = feed["passCliVersions"]
        version = release["version"]
        source = release["urls"]["linux"]["x86_64"]
        url = source["url"]
        checksum = source["hash"]
        algorithm = "sha256"
    else:
        categories = {"Stable"}
        if channel == "beta":
            categories.add(BETA_CATEGORIES[package])
        releases = [release for release in feed["Releases"] if release["CategoryName"] in categories]
        if not releases:
            raise ValueError(f"No {channel} release for {package}")
        # Prefer stable metadata when a version is published in both categories.
        release = max(releases, key=lambda release: (
            version_key(release["Version"]), release["CategoryName"] == "Stable"
        ))
        version = release["Version"]
        expected_url = template.format(version=version)
        sources = [source for source in release["File"] if source["Url"] == expected_url]
        if len(sources) != 1:
            raise ValueError(f"Expected exactly one official DEB for {package} {version}")
        source = sources[0]
        url = source["Url"]
        checksum = source["Sha512CheckSum"]
        algorithm = "sha512"

    version_key(version)
    if url != template.format(version=version):
        raise ValueError(f"Unexpected download URL for {package}: {url}")
    length = 64 if algorithm == "sha256" else 128
    if not isinstance(checksum, str) or not re.fullmatch(rf"[0-9a-fA-F]{{{length}}}", checksum):
        raise ValueError(f"Invalid {algorithm} checksum for {package}")
    # Pin Proton's checksum directly; Nix verifies the downloaded binary at build time.
    hash_value = algorithm + "-" + base64.b64encode(bytes.fromhex(checksum)).decode("ascii")
    return version, hash_value


def validate_update(package, current_version, current_hash, version, hash_value):
    if version_key(version) < version_key(current_version):
        raise ValueError(f"Refusing to downgrade {package} from {current_version} to {version}")
    if version == current_version and hash_value != current_hash:
        raise ValueError(f"Checksum changed for existing {package} {version}")


def updated_releases(package, text, feed):
    releases = json.loads(text)
    if set(releases) != {"stable", "beta"}:
        raise ValueError(f"Unexpected release channels for {package}")
    for channel, current in releases.items():
        version, hash_value = release_source(package, feed, channel)
        validate_update(f"{package} ({channel})", current["version"], current["hash"], version, hash_value)
        releases[channel] = {"version": version, "hash": hash_value}
    return json.dumps(releases, indent=2) + "\n"


def updated_package(package, text, feed, signature_hash=None):
    version, hash_value = release_source(package, feed)
    versions = VERSION_DECLARATION.findall(text)
    hashes = HASH_DECLARATION.findall(text)
    expected_url = PACKAGES[package][1].replace("{version}", "${finalAttrs.version}")
    if len(versions) != 1 or len(hashes) != 1 or text.count(f'    url = "{expected_url}";') != 1:
        raise ValueError(f"Unexpected package declarations for {package}")
    validate_update(package, versions[0], hashes[0], version, hash_value)
    if package == "protonmail-bridge":
        if signature_hash is None or len(SIGNATURE_DECLARATION.findall(text)) != 1:
            raise ValueError("Expected a pinned Bridge DEB signature")
        text = SIGNATURE_DECLARATION.sub(f'  signatureHash = "{signature_hash}";', text)
    text = VERSION_DECLARATION.sub(f'  version = "{version}";', text)
    return HASH_DECLARATION.sub(f'    hash = "{hash_value}";', text)


def update_packages(root):
    updates = []
    for package, (feed_url, _) in PACKAGES.items():
        with urlopen(feed_url, timeout=60) as response:
            payload = response.read()
        signature_hash = None
        if package == "protonmail-bridge":
            with urlopen(feed_url + ".sig", timeout=60) as response:
                feed_signature = response.read()
            verify_bridge_feed(payload, feed_signature, root / "pkgs" / package / "release-key.asc")
        feed = json.loads(payload)
        if package == "protonmail-bridge":
            version, _ = release_source(package, feed)
            binary_url = PACKAGES[package][1].format(version=version)
            with urlopen(binary_url + ".sig", timeout=60) as response:
                signature_hash = "sha256-" + base64.b64encode(hashlib.sha256(response.read()).digest()).decode("ascii")
        filename = "releases.json" if package in BETA_CATEGORIES else "default.nix"
        path = root / "pkgs" / package / filename
        original = path.read_text()
        if package in BETA_CATEGORIES:
            updated = updated_releases(package, original, feed)
        else:
            updated = updated_package(package, original, feed, signature_hash)
        if updated != original:
            updates.append((path, updated))
        channels = ("stable", "beta") if package in BETA_CATEGORIES else ("stable",)
        for channel in channels:
            print(f"{package} ({channel}): {release_source(package, feed, channel)[0]}")

    # Validate every feed before modifying any package.
    for path, text in updates:
        path.write_text(text)


if __name__ == "__main__":
    update_packages(Path(__file__).resolve().parent.parent)

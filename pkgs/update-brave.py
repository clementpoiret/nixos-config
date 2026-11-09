#!/usr/bin/env python3
"""Pin Brave's stable Linux DEB after verifying its signed checksum."""

import hashlib
import json
from pathlib import Path
import re
import sys
import tempfile
from time import sleep
from urllib.error import HTTPError
from urllib.request import urlopen

from verify_signature import verify_signature


VERSION_URL = "https://versions.brave.com/latest/release-linux-x64.version"
RELEASE_URL = "https://github.com/brave/brave-browser/releases/download"


def fetch_metadata(url):
    for attempt in range(4):
        try:
            with urlopen(url, timeout=60) as response:
                return response.read()
        except HTTPError as error:
            error.close()
            if error.code not in (408, 429, 500, 502, 503, 504) or attempt == 3:
                raise
            delay = 2 ** (attempt + 1)
            print(f"Download failed for {url}: {error}; retrying in {delay}s", file=sys.stderr)
            sleep(delay)


def version_key(version):
    if not isinstance(version, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError(f"Invalid stable Brave version: {version!r}")
    return tuple(map(int, version.split(".")))


def release_pin(version, checksum, signature, key):
    version_key(version)
    filename = f"brave-browser_{version}_amd64.deb"
    with tempfile.TemporaryDirectory(prefix="brave-release-") as directory:
        checksum_path = Path(directory) / "checksum"
        signature_path = Path(directory) / "signature"
        checksum_path.write_bytes(checksum)
        signature_path.write_bytes(signature)
        verify_signature(key, signature_path, checksum_path)
    match = re.fullmatch(rf"([0-9a-f]{{64}})  {re.escape(filename)}\n?", checksum.decode("ascii"))
    if not match:
        raise ValueError("Unexpected signed Brave checksum or filename")
    return {
        "version": version,
        "sha256": match[1],
        "checksumSha256": hashlib.sha256(checksum).hexdigest(),
        "signatureSha256": hashlib.sha256(signature).hexdigest(),
    }


def update_release(package):
    path = package / "release.json"
    current = json.loads(path.read_text())
    version = fetch_metadata(VERSION_URL).decode("ascii").strip()
    if version_key(version) < version_key(current["version"]):
        raise ValueError(f"Refusing to downgrade Brave from {current['version']} to {version}")
    url = f"{RELEASE_URL}/v{version}/brave-browser_{version}_amd64.deb"
    checksum = fetch_metadata(url + ".sha256")
    signature = fetch_metadata(url + ".sha256.asc")
    updated = release_pin(version, checksum, signature, package / "release-key.asc")
    if version == current["version"] and updated["sha256"] != current["sha256"]:
        raise ValueError(f"Checksum changed for existing Brave {version}")
    if updated != current:
        path.write_text(json.dumps(updated, indent=2) + "\n")
    print(f"brave: {version} (release signature verified)")


if __name__ == "__main__":
    update_release(Path(__file__).resolve().parent / "brave")

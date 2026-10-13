import base64
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch


SOURCE = Path(os.environ.get("PROTON_UPDATER_SOURCE", Path(__file__).parent.parent / "pkgs/update-proton.py"))
sys.path.insert(0, str(SOURCE.parent))
updater = runpy.run_path(str(SOURCE))
PACKAGES = updater["PACKAGES"]


def release(package, version, category="Stable"):
    return {
        "CategoryName": category,
        "Version": version,
        "File": [{
            "Url": PACKAGES[package][1].format(version=version),
            "Sha512CheckSum": "ab" * 64,
        }],
    }


def feed(package, version="2.0.0"):
    if package == "proton-pass-cli":
        return {"passCliVersions": {
            "version": version,
            "urls": {"linux": {"x86_64": {
                "url": PACKAGES[package][1].format(version=version),
                "hash": "ab" * 32,
            }}},
        }}
    return {"Releases": [release(package, version)]}


def package_text(package, version="1.0.0"):
    text = (
        f'  version = "{version}";\n'
        '  src = fetchurl {\n'
        f'    url = "{PACKAGES[package][1].replace("{version}", "${finalAttrs.version}")}";\n'
        '    hash = "sha256-old";\n'
        '  };\n'
    )
    if package == "protonmail-bridge":
        text += '  signatureHash = "sha256-old";\n'
    return text


class ProtonUpdateTests(unittest.TestCase):
    def test_selects_highest_stable_version_for_each_desktop_package(self):
        for package in PACKAGES:
            if package == "proton-pass-cli":
                continue
            with self.subTest(package=package):
                metadata = {"Releases": [
                    release(package, "4.0.0", "Alpha"),
                    release(package, "1.9.0"),
                    release(package, "1.11.0"),
                    release(package, "3.0.0", "EarlyAccess"),
                ]}
                version, checksum = updater["release_source"](package, metadata)
                self.assertEqual(version, "1.11.0")
                self.assertEqual(checksum, "sha512-" + base64.b64encode(bytes.fromhex("ab" * 64)).decode())

    def test_selects_linux_x86_64_cli_binary_and_sha256(self):
        version, checksum = updater["release_source"]("proton-pass-cli", feed("proton-pass-cli"))
        self.assertEqual(version, "2.0.0")
        self.assertEqual(checksum, "sha256-" + base64.b64encode(bytes.fromhex("ab" * 32)).decode())

    def test_rejects_missing_stable_release_and_duplicate_installer(self):
        metadata = feed("proton-pass")
        metadata["Releases"][0]["CategoryName"] = "Beta"
        with self.assertRaisesRegex(ValueError, "No stable release"):
            updater["release_source"]("proton-pass", metadata)
        metadata = feed("proton-pass")
        metadata["Releases"][0]["File"] *= 2
        with self.assertRaisesRegex(ValueError, "exactly one official DEB"):
            updater["release_source"]("proton-pass", metadata)

    def test_rejects_invalid_versions_checksums_and_download_urls(self):
        for package in PACKAGES:
            metadata = feed(package)
            if package == "proton-pass-cli":
                item = metadata["passCliVersions"]["urls"]["linux"]["x86_64"]
                url_key, hash_key = "url", "hash"
            else:
                item = metadata["Releases"][0]["File"][0]
                url_key, hash_key = "Url", "Sha512CheckSum"
            for field, value in [(url_key, "https://example.com/binary"), (hash_key, "invalid")]:
                with self.subTest(package=package, field=field):
                    original = item[field]
                    item[field] = value
                    with self.assertRaises(ValueError):
                        updater["release_source"](package, metadata)
                    item[field] = original
            with self.subTest(package=package, field="version"):
                with self.assertRaisesRegex(ValueError, "Invalid stable version"):
                    updater["release_source"](package, feed(package, "2.0.0-beta"))

    def test_updates_only_version_and_hash_and_is_idempotent(self):
        for package in PACKAGES:
            with self.subTest(package=package):
                original = package_text(package)
                updated = updater["updated_package"](package, original, feed(package), "sha256-signature")
                self.assertIn('  version = "2.0.0";', updated)
                self.assertEqual(original.splitlines()[1:3], updated.splitlines()[1:3])
                self.assertEqual(updater["updated_package"](package, updated, feed(package), "sha256-signature"), updated)

    def test_rejects_downgrades_republished_binaries_and_unexpected_declarations(self):
        package = "proton-pass"
        with self.assertRaisesRegex(ValueError, "Refusing to downgrade"):
            updater["updated_package"](package, package_text(package, "3.0.0"), feed(package))
        with self.assertRaisesRegex(ValueError, "Checksum changed"):
            updater["updated_package"](package, package_text(package, "2.0.0"), feed(package))
        for text in [package_text(package) * 2, package_text(package).replace("proton.me", "example.com")]:
            with self.assertRaisesRegex(ValueError, "Unexpected package declarations"):
                updater["updated_package"](package, text, feed(package))

    def test_validates_all_feeds_before_writing_any_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for package in PACKAGES:
                path = root / "pkgs" / package / "default.nix"
                path.parent.mkdir(parents=True)
                path.write_text(package_text(package))
            metadata = [feed(package) for package in PACKAGES]
            metadata[-1]["passCliVersions"]["urls"]["linux"]["x86_64"]["hash"] = "invalid"
            responses = {PACKAGES[package][0]: json.dumps(item).encode() for package, item in zip(PACKAGES, metadata)}
            bridge_feed_url, bridge_binary_url = PACKAGES["protonmail-bridge"]
            responses[bridge_feed_url + ".sig"] = b"feed-signature"
            responses[bridge_binary_url.format(version="2.0.0") + ".sig"] = b"binary-signature"
            fetch = Mock(side_effect=lambda url, **_: io.BytesIO(responses[url]))
            with patch.dict(updater["update_packages"].__globals__, urlopen=fetch, verify_bridge_feed=Mock()):
                with self.assertRaisesRegex(ValueError, "Invalid sha256 checksum"):
                    updater["update_packages"](root)
            for package in PACKAGES:
                self.assertEqual((root / "pkgs" / package / "default.nix").read_text(), package_text(package))

    def test_rejects_unverified_bridge_metadata_before_writing_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for package in PACKAGES:
                path = root / "pkgs" / package / "default.nix"
                path.parent.mkdir(parents=True)
                path.write_text(package_text(package))
            responses = {url: json.dumps(feed(package)).encode() for package, (url, _) in PACKAGES.items()}
            responses[PACKAGES["protonmail-bridge"][0] + ".sig"] = b"invalid-signature"
            fetch = Mock(side_effect=lambda url, **_: io.BytesIO(responses[url]))
            verify = Mock(side_effect=subprocess.CalledProcessError(1, "gpgv"))
            with patch.dict(updater["update_packages"].__globals__, urlopen=fetch, verify_bridge_feed=verify):
                with self.assertRaises(subprocess.CalledProcessError):
                    updater["update_packages"](root)
            verify.assert_called_once()
            for package in PACKAGES:
                self.assertEqual((root / "pkgs" / package / "default.nix").read_text(), package_text(package))


if __name__ == "__main__":
    unittest.main()

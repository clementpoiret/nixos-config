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
BETA_CATEGORIES = {
    "proton-pass": "Beta",
    "protonmail-desktop": "EarlyAccess",
}


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
    if package in BETA_CATEGORIES:
        return json.dumps({
            channel: {"version": version, "hash": "sha512-old"}
            for channel in ("stable", "beta")
        }, indent=2) + "\n"
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


def package_path(root, package):
    filename = "releases.json" if package in BETA_CATEGORIES else "default.nix"
    return root / "pkgs" / package / filename


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
                    release(package, "2.0.0", "Beta"),
                    release(package, "3.0.0", "EarlyAccess"),
                ]}
                version, checksum = updater["release_source"](package, metadata)
                self.assertEqual(version, "1.11.0")
                self.assertEqual(checksum, "sha512-" + base64.b64encode(bytes.fromhex("ab" * 64)).decode())

    def test_beta_selects_highest_stable_or_package_specific_prerelease(self):
        for package, category in BETA_CATEGORIES.items():
            other_category = "Beta" if category == "EarlyAccess" else "EarlyAccess"
            for stable, beta, expected in [
                ("1.9.0", "1.11.0", "1.11.0"),
                ("1.11.0", "1.9.0", "1.11.0"),
            ]:
                with self.subTest(package=package, stable=stable, beta=beta):
                    metadata = {"Releases": [
                        release(package, "5.0.0", "Alpha"),
                        release(package, "4.0.0", other_category),
                        release(package, stable),
                        release(package, beta, category),
                    ]}
                    self.assertEqual(updater["release_source"](package, metadata, "beta")[0], expected)
            self.assertEqual(updater["release_source"](package, feed(package), "beta")[0], "2.0.0")

    def test_beta_prefers_stable_metadata_when_version_is_promoted(self):
        for package, category in BETA_CATEGORIES.items():
            with self.subTest(package=package):
                stable = release(package, "2.0.0")
                beta = release(package, "2.0.0", category)
                beta["File"][0]["Sha512CheckSum"] = ""
                for releases in ([beta, stable], [stable, beta]):
                    self.assertEqual(
                        updater["release_source"](package, {"Releases": releases}, "beta"),
                        updater["release_source"](package, {"Releases": [stable]}),
                    )

    def test_rejects_unsupported_channels(self):
        for package, channel in [("proton-pass", "alpha"), ("protonmail-bridge", "beta"), ("proton-pass-cli", "beta")]:
            with self.subTest(package=package, channel=channel):
                with self.assertRaisesRegex(ValueError, "Unsupported release channel"):
                    updater["release_source"](package, feed(package), channel)

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
                with self.assertRaisesRegex(ValueError, "Invalid release version"):
                    updater["release_source"](package, feed(package, "2.0.0-beta"))

    def test_updates_only_version_and_hash_and_is_idempotent(self):
        for package in PACKAGES:
            if package in BETA_CATEGORIES:
                continue
            with self.subTest(package=package):
                original = package_text(package)
                updated = updater["updated_package"](package, original, feed(package), "sha256-signature")
                self.assertIn('  version = "2.0.0";', updated)
                self.assertEqual(original.splitlines()[1:3], updated.splitlines()[1:3])
                self.assertEqual(updater["updated_package"](package, updated, feed(package), "sha256-signature"), updated)

    def test_rejects_downgrades_republished_binaries_and_unexpected_declarations(self):
        package = "proton-pass-cli"
        with self.assertRaisesRegex(ValueError, "Refusing to downgrade"):
            updater["updated_package"](package, package_text(package, "3.0.0"), feed(package))
        with self.assertRaisesRegex(ValueError, "Checksum changed"):
            updater["updated_package"](package, package_text(package, "2.0.0"), feed(package))
        for text in [package_text(package) * 2, package_text(package).replace("proton.me", "example.com")]:
            with self.assertRaisesRegex(ValueError, "Unexpected package declarations"):
                updater["updated_package"](package, text, feed(package))

    def test_updates_channel_pins_independently_and_is_idempotent(self):
        for package, category in BETA_CATEGORIES.items():
            with self.subTest(package=package):
                metadata = {"Releases": [release(package, "2.0.0"), release(package, "3.0.0", category)]}
                updated = updater["updated_releases"](package, package_text(package), metadata)
                pins = json.loads(updated)
                self.assertEqual(pins["stable"]["version"], "2.0.0")
                self.assertEqual(pins["beta"]["version"], "3.0.0")
                self.assertEqual(pins["beta"]["hash"], "sha512-" + base64.b64encode(bytes.fromhex("ab" * 64)).decode())
                self.assertEqual(updater["updated_releases"](package, updated, metadata), updated)

    def test_rejects_downgrades_and_republished_binaries_for_each_channel(self):
        for package in BETA_CATEGORIES:
            for channel in ("stable", "beta"):
                for version, message in [("3.0.0", "Refusing to downgrade"), ("2.0.0", "Checksum changed")]:
                    with self.subTest(package=package, channel=channel, version=version):
                        pins = json.loads(package_text(package))
                        pins[channel]["version"] = version
                        with self.assertRaisesRegex(ValueError, message):
                            updater["updated_releases"](package, json.dumps(pins), feed(package))

    def test_rejects_invalid_beta_sources_and_unexpected_channels(self):
        for package, category in BETA_CATEGORIES.items():
            for field, value in [("Url", "https://example.com/binary"), ("Sha512CheckSum", "invalid")]:
                with self.subTest(package=package, field=field):
                    beta = release(package, "3.0.0", category)
                    beta["File"][0][field] = value
                    with self.assertRaises(ValueError):
                        updater["updated_releases"](package, package_text(package), {
                            "Releases": [release(package, "2.0.0"), beta],
                        })
            pins = json.loads(package_text(package))
            pins["alpha"] = pins["beta"]
            with self.assertRaisesRegex(ValueError, "Unexpected release channels"):
                updater["updated_releases"](package, json.dumps(pins), feed(package))

    def test_validates_all_feeds_before_writing_any_packages(self):
        for invalid_source in ("cli", "beta"):
            with self.subTest(source=invalid_source), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                for package in PACKAGES:
                    path = package_path(root, package)
                    path.parent.mkdir(parents=True)
                    path.write_text(package_text(package))
                metadata = {package: feed(package) for package in PACKAGES}
                if invalid_source == "cli":
                    metadata["proton-pass-cli"]["passCliVersions"]["urls"]["linux"]["x86_64"]["hash"] = "invalid"
                    error = "Invalid sha256 checksum"
                else:
                    beta = release("protonmail-desktop", "3.0.0", "EarlyAccess")
                    beta["File"][0]["Sha512CheckSum"] = "invalid"
                    metadata["protonmail-desktop"]["Releases"].append(beta)
                    error = "Invalid sha512 checksum"
                responses = {PACKAGES[package][0]: json.dumps(item).encode() for package, item in metadata.items()}
                bridge_feed_url, bridge_binary_url = PACKAGES["protonmail-bridge"]
                responses[bridge_feed_url + ".sig"] = b"feed-signature"
                responses[bridge_binary_url.format(version="2.0.0") + ".sig"] = b"binary-signature"
                fetch = Mock(side_effect=lambda url, **_: io.BytesIO(responses[url]))
                with patch.dict(updater["update_packages"].__globals__, urlopen=fetch, verify_bridge_feed=Mock()):
                    with self.assertRaisesRegex(ValueError, error):
                        updater["update_packages"](root)
                for package in PACKAGES:
                    self.assertEqual(package_path(root, package).read_text(), package_text(package))

    def test_updates_all_packages_and_channels_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for package in PACKAGES:
                path = package_path(root, package)
                path.parent.mkdir(parents=True)
                path.write_text(package_text(package))
            metadata = {package: feed(package) for package in PACKAGES}
            for package, category in BETA_CATEGORIES.items():
                metadata[package]["Releases"].append(release(package, "3.0.0", category))
            responses = {PACKAGES[package][0]: json.dumps(item).encode() for package, item in metadata.items()}
            bridge_feed_url, bridge_binary_url = PACKAGES["protonmail-bridge"]
            responses[bridge_feed_url + ".sig"] = b"feed-signature"
            responses[bridge_binary_url.format(version="2.0.0") + ".sig"] = b"binary-signature"
            fetch = Mock(side_effect=lambda url, **_: io.BytesIO(responses[url]))
            with patch.dict(updater["update_packages"].__globals__, urlopen=fetch, verify_bridge_feed=Mock()):
                updater["update_packages"](root)
                updated = {package: package_path(root, package).read_text() for package in PACKAGES}
                updater["update_packages"](root)
            for package in PACKAGES:
                self.assertEqual(package_path(root, package).read_text(), updated[package])
                if package in BETA_CATEGORIES:
                    pins = json.loads(updated[package])
                    self.assertEqual(pins["stable"]["version"], "2.0.0")
                    self.assertEqual(pins["beta"]["version"], "3.0.0")
                else:
                    self.assertIn('  version = "2.0.0";', updated[package])

    def test_rejects_unverified_bridge_metadata_before_writing_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for package in PACKAGES:
                path = package_path(root, package)
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
                self.assertEqual(package_path(root, package).read_text(), package_text(package))


if __name__ == "__main__":
    unittest.main()

import io
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch


ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT / "pkgs"))
from verify_signature import verify_signature

brave = runpy.run_path(os.environ.get("BRAVE_UPDATER_SOURCE", str(ROOT / "pkgs/update-brave.py")))
proton = runpy.run_path(os.environ.get("PROTON_UPDATER_SOURCE", str(ROOT / "pkgs/update-proton.py")))
BRAVE_KEY = Path(os.environ.get("BRAVE_RELEASE_KEY", ROOT / "pkgs/brave/release-key.asc"))
BRIDGE_KEY = Path(os.environ.get("BRIDGE_RELEASE_KEY", ROOT / "pkgs/protonmail-bridge/release-key.asc"))
FIXTURES = Path(os.environ.get("RELEASE_SIGNATURE_FIXTURES", ROOT / "tests/fixtures/release-signatures"))


class ReleaseSignatureTests(unittest.TestCase):
    def test_accepts_official_release_signature(self):
        verify_signature(BRAVE_KEY, FIXTURES / "brave.sha256.asc", FIXTURES / "brave.sha256")

    def test_rejects_tampered_checksum(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "checksum"
            path.write_bytes((FIXTURES / "brave.sha256").read_bytes() + b"tampered")
            with self.assertRaises(subprocess.CalledProcessError):
                verify_signature(BRAVE_KEY, FIXTURES / "brave.sha256.asc", path)

    def test_rejects_untrusted_signer(self):
        with self.assertRaises(subprocess.CalledProcessError):
            verify_signature(BRIDGE_KEY, FIXTURES / "brave.sha256.asc", FIXTURES / "brave.sha256")

    def test_verifies_bridge_metadata_before_parsing(self):
        payload = (FIXTURES / "bridge-version.json").read_bytes()
        signature = (FIXTURES / "bridge-version.json.sig").read_bytes()
        proton["verify_bridge_feed"](payload, signature, BRIDGE_KEY)
        with self.assertRaises(subprocess.CalledProcessError):
            proton["verify_bridge_feed"](payload + b" ", signature, BRIDGE_KEY)


class BraveUpdateTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.package = Path(directory.name)
        shutil.copyfile(BRAVE_KEY, self.package / "release-key.asc")
        self.manifest = self.package / "release.json"
        self.current = {
            "version": "1.96.61",
            "sha256": "0" * 64,
            "checksumSha256": "0" * 64,
            "signatureSha256": "0" * 64,
        }
        self.checksum = (FIXTURES / "brave.sha256").read_bytes()
        self.signature = (FIXTURES / "brave.sha256.asc").read_bytes()

    def run_update(self, version="1.97.56", signature=None):
        responses = [version.encode(), self.checksum, self.signature if signature is None else signature]
        fetch = Mock(side_effect=[io.BytesIO(response) for response in responses])
        with patch.dict(brave["update_release"].__globals__, urlopen=fetch):
            brave["update_release"](self.package)
        return fetch

    def test_updates_verified_release_and_is_idempotent(self):
        self.manifest.write_text(json.dumps(self.current))
        fetch = self.run_update()
        self.assertEqual(fetch.call_args_list[0].args[0], brave["VERSION_URL"])
        updated = self.manifest.read_bytes()
        manifest = json.loads(updated)
        self.assertEqual(manifest["version"], "1.97.56")
        self.assertEqual(manifest["sha256"], "30e4cb89db380567e6fcdaab7110a17d6250517e22860c6bdb02eadf8993b669")
        self.run_update()
        self.assertEqual(self.manifest.read_bytes(), updated)

    def test_rejects_invalid_signature_without_changing_pin(self):
        original = json.dumps(self.current)
        self.manifest.write_text(original)
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_update(signature=b"invalid-signature")
        self.assertEqual(self.manifest.read_text(), original)

    def test_rejects_wrong_filename_even_with_valid_signature(self):
        with self.assertRaisesRegex(ValueError, "Unexpected signed Brave checksum or filename"):
            brave["release_pin"]("1.97.55", self.checksum, self.signature, BRAVE_KEY)

    def test_rejects_prerelease_versions_and_downgrades(self):
        self.manifest.write_text(json.dumps(self.current))
        with self.assertRaisesRegex(ValueError, "Invalid stable Brave version"):
            self.run_update(version="1.97.56-beta")
        self.current["version"] = "1.98.0"
        original = json.dumps(self.current)
        self.manifest.write_text(original)
        with self.assertRaisesRegex(ValueError, "Refusing to downgrade"):
            self.run_update()
        self.assertEqual(self.manifest.read_text(), original)

    def test_rejects_republished_binary_without_changing_pin(self):
        self.current["version"] = "1.97.56"
        original = json.dumps(self.current)
        self.manifest.write_text(original)
        with self.assertRaisesRegex(ValueError, "Checksum changed for existing Brave"):
            self.run_update()
        self.assertEqual(self.manifest.read_text(), original)


if __name__ == "__main__":
    unittest.main()

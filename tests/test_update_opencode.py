import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).parent.parent
updater = runpy.run_path(os.environ.get("OPENCODE_UPDATER_SOURCE", str(ROOT / "pkgs/update-opencode.py")))


def release(tag, **flags):
    return {"tag_name": tag, "draft": False, "prerelease": False, **flags}


class OpenCodeUpdateTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.flake = Path(directory.name) / "flake.nix"

    def pin(self, ref):
        content = (
            '{\n    opencode = {\n'
            f'      url = "github:anomalyco/opencode/{ref}";\n'
            '    };\n    herdr = {\n'
            '      url = "github:herdrdev/herdr/v0.9.5";\n'
            '    };\n}\n'
        )
        self.flake.write_text(content)
        return content

    def test_selects_highest_stable_release_and_preserves_other_inputs(self):
        releases = [
            release("v1.19.5"),
            release("v2.2.0"),
            release("v2.10.0"),
            release("v2.9.0"),
            release("v3.0.0-beta.1"),
            release("v4.0.0", draft=True),
            release("v5.0.0", prerelease=True),
        ]
        for current in (updater["BOOTSTRAP_REVISION"], "v2.9.0"):
            with self.subTest(current=current):
                original = self.pin(current)
                updater["update_release"](self.flake, releases)
                expected = original.replace(f"opencode/{current}", "opencode/v2.10.0")
                self.assertEqual(self.flake.read_text(), expected)
                updater["update_release"](self.flake, releases)
                self.assertEqual(self.flake.read_text(), expected)

    def test_keeps_verified_revision_until_a_newer_release(self):
        original = self.pin(updater["BOOTSTRAP_REVISION"])
        updater["update_release"](self.flake, [release("v1.19.5"), release("v2.2.0")])
        self.assertEqual(self.flake.read_text(), original)

    def test_does_not_downgrade_a_release_pin(self):
        original = self.pin("v2.3.0")
        updater["update_release"](self.flake, [release("v1.19.5"), release("v2.2.0")])
        self.assertEqual(self.flake.read_text(), original)

    def test_rejects_unknown_or_ambiguous_pins_without_changes(self):
        for current in ("dev", "a" * 40):
            with self.subTest(current=current):
                original = self.pin(current)
                with self.assertRaisesRegex(ValueError, "Unknown OpenCode pin"):
                    updater["update_release"](self.flake, [release("v2.3.0")])
                self.assertEqual(self.flake.read_text(), original)
        original = self.pin("v2.2.0") * 2
        self.flake.write_text(original)
        with self.assertRaisesRegex(ValueError, "exactly one"):
            updater["update_release"](self.flake, [release("v2.3.0")])
        self.assertEqual(self.flake.read_text(), original)

    def test_rejects_missing_stable_releases_without_changes(self):
        original = self.pin(updater["BOOTSTRAP_REVISION"])
        with self.assertRaisesRegex(ValueError, "No stable OpenCode releases"):
            updater["update_release"](self.flake, [
                release("v2.3.0-beta.1"),
                release("v2.3.0", prerelease=True),
                release("v2.4.0", draft=True),
            ])
        self.assertEqual(self.flake.read_text(), original)

    def test_reads_paginated_release_metadata(self):
        releases = [release("v1.19.5"), release("v2.3.0"), release("v2.4.0", draft=True)]
        output = "\n".join(json.dumps(item) for item in releases) + "\n"
        with patch("subprocess.check_output", return_value=output) as fetch:
            self.assertEqual(updater["fetch_releases"](), releases)
        self.assertIn("--paginate", fetch.call_args.args[0])


if __name__ == "__main__":
    unittest.main()

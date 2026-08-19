from __future__ import annotations

import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(
    os.environ.get(
        "NIXOS_CONFIG_AGENT_SOURCE",
        Path(__file__).parents[1] / "modules/home/scripts/nixos_config_agent.py",
    )
)
SPEC = importlib.util.spec_from_file_location("nixos_config_agent", SOURCE)
assert SPEC is not None and SPEC.loader is not None
nixos_config_agent = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = nixos_config_agent
SPEC.loader.exec_module(nixos_config_agent)


class NixosConfigAgentTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.protected = self.root / "nixos-config"
        self.candidate = self.root / "nixos-config-writable"
        config = self.root / "jj-config.toml"
        config.write_text(
            'user.name = "Promotion Test"\nuser.email = "promotion@example.invalid"\n',
            encoding="utf-8",
        )
        self.old_config = os.environ.get("JJ_CONFIG")
        self.old_home = os.environ.get("HOME")
        test_home = self.root / "home"
        test_home.mkdir()
        os.environ["HOME"] = str(test_home)
        os.environ["JJ_CONFIG"] = str(config)
        self.addCleanup(self._restore_config)

        self.run_jj(None, "git", "init", "--colocate", str(self.protected))
        (self.protected / "configuration.nix").write_text("baseline\n", encoding="utf-8")
        self.run_jj(self.protected, "describe", "-m", "feat: establish baseline")
        self.run_jj(self.protected, "new", "-m", "")

    def _restore_config(self) -> None:
        if self.old_config is None:
            os.environ.pop("JJ_CONFIG", None)
        else:
            os.environ["JJ_CONFIG"] = self.old_config
        if self.old_home is None:
            os.environ.pop("HOME", None)
        else:
            os.environ["HOME"] = self.old_home

    def run_jj(self, repo: Path | None, *arguments: str) -> str:
        command = ["jj", "--no-pager", "--color=never"]
        if repo is not None:
            command.extend(("-R", str(repo)))
        command.extend(arguments)
        return subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        ).stdout

    def initialize(self) -> str:
        return nixos_config_agent.initialize(
            self.protected,
            self.candidate,
            check_profile=False,
        )

    def describe_candidate(self, subject: str = "fix(apparmor): tighten policy") -> str:
        (self.candidate / "configuration.nix").write_text("candidate\n", encoding="utf-8")
        self.run_jj(self.candidate, "describe", "-m", subject)
        return nixos_config_agent.one_revision(
            self.candidate, "@", "candidate working-copy"
        )

    def test_initializes_exact_baseline_and_promotes_one_reviewed_change(self) -> None:
        baseline = self.initialize()
        self.assertTrue(nixos_config_agent.is_empty(self.candidate))
        self.assertEqual(
            nixos_config_agent.one_revision(
                self.candidate, "parents(@)", "candidate baseline"
            ),
            baseline,
        )
        candidate_id = self.describe_candidate()

        promoted = nixos_config_agent.promote(
            self.protected,
            self.candidate,
            confirm=lambda _: candidate_id,
            output=io.StringIO(),
            check_profile=False,
            require_tty=False,
        )

        self.assertEqual(promoted, candidate_id)
        self.assertEqual(
            (self.protected / "configuration.nix").read_text(encoding="utf-8"),
            "candidate\n",
        )
        self.assertTrue(nixos_config_agent.is_empty(self.protected))
        self.assertTrue(nixos_config_agent.is_empty(self.candidate))
        self.assertEqual(
            nixos_config_agent.one_revision(
                self.protected, "parents(@)", "protected promoted parent"
            ),
            candidate_id,
        )
        self.assertEqual(
            nixos_config_agent.one_revision(
                self.candidate, "parents(@)", "candidate promoted parent"
            ),
            candidate_id,
        )

    def test_refuses_existing_destination(self) -> None:
        self.candidate.mkdir()
        with self.assertRaisesRegex(
            nixos_config_agent.WorkflowError, "destination already exists"
        ):
            self.initialize()

    def test_refuses_empty_or_nonconventional_candidate(self) -> None:
        self.initialize()
        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "change is empty"):
            nixos_config_agent.promote(
                self.protected,
                self.candidate,
                confirm=lambda _: "",
                output=io.StringIO(),
                check_profile=False,
                require_tty=False,
            )

        self.describe_candidate("not a conventional subject")
        with self.assertRaisesRegex(
            nixos_config_agent.WorkflowError, "Conventional Commit"
        ):
            nixos_config_agent.promote(
                self.protected,
                self.candidate,
                confirm=lambda _: "",
                output=io.StringIO(),
                check_profile=False,
                require_tty=False,
            )

    def test_rejection_and_stale_baseline_leave_protected_tree_unchanged(self) -> None:
        self.initialize()
        candidate_id = self.describe_candidate()
        protected_before = nixos_config_agent.one_revision(
            self.protected, "@", "protected working-copy"
        )
        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "did not match"):
            nixos_config_agent.promote(
                self.protected,
                self.candidate,
                confirm=lambda _: "no",
                output=io.StringIO(),
                check_profile=False,
                require_tty=False,
            )
        self.assertEqual(
            nixos_config_agent.one_revision(
                self.protected, "@", "protected working-copy"
            ),
            protected_before,
        )

        (self.protected / "configuration.nix").write_text("new baseline\n", encoding="utf-8")
        self.run_jj(self.protected, "describe", "-m", "fix: advance protected")
        self.run_jj(self.protected, "new", "-m", "")
        stale_protected = nixos_config_agent.one_revision(
            self.protected, "@", "protected working-copy"
        )
        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "does not match"):
            nixos_config_agent.promote(
                self.protected,
                self.candidate,
                confirm=lambda _: candidate_id,
                output=io.StringIO(),
                check_profile=False,
                require_tty=False,
            )
        self.assertEqual(
            nixos_config_agent.one_revision(
                self.protected, "@", "protected working-copy"
            ),
            stale_protected,
        )

    def test_requires_unconfined_label(self) -> None:
        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "must run unconfined"):
            nixos_config_agent.require_unconfined(lambda: "local-codex-cli (complain)")


if __name__ == "__main__":
    unittest.main()

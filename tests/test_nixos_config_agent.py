from __future__ import annotations

import importlib.util
import io
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

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
        self.github = self.root / "github.git"
        self.config = self.root / "jj-config.toml"
        self.signing_key = self.root / "signing-key"

        subprocess.run(
            [
                "ssh-keygen",
                "-q",
                "-t",
                "ed25519",
                "-N",
                "",
                "-f",
                str(self.signing_key),
            ],
            check=True,
        )
        self.config.write_text(
            "\n".join(
                (
                    'user.name = "Promotion Test"',
                    'user.email = "promotion@example.invalid"',
                    "git.sign-on-push = true",
                    'signing.backend = "ssh"',
                    'signing.behavior = "drop"',
                    f'signing.key = "{self.signing_key}"',
                    "",
                )
            ),
            encoding="utf-8",
        )
        test_home = self.root / "home"
        test_home.mkdir()
        self.enterContext(
            mock.patch.dict(
                os.environ,
                {"HOME": str(test_home), "JJ_CONFIG": str(self.config)},
            )
        )

        subprocess.run(
            ["git", "init", "--bare", "--quiet", str(self.github)],
            check=True,
        )
        self.run_jj(None, "git", "init", "--colocate", str(self.protected))
        (self.protected / "configuration.nix").write_text(
            "baseline\n", encoding="utf-8"
        )
        self.run_jj(self.protected, "describe", "-m", "feat: establish baseline")
        self.run_jj(self.protected, "new", "-m", "")
        self.run_jj(
            self.protected,
            "git",
            "remote",
            "add",
            nixos_config_agent.UPSTREAM_REMOTE,
            str(self.github),
        )
        self.run_jj(
            self.protected,
            "bookmark",
            "create",
            nixos_config_agent.MAIN_BOOKMARK,
            "-r",
            "@-",
        )
        self.run_jj(
            self.protected,
            "--config",
            "git.sign-on-push=false",
            "git",
            "push",
            "--remote",
            nixos_config_agent.UPSTREAM_REMOTE,
            "--bookmark",
            f"exact:{nixos_config_agent.MAIN_BOOKMARK}",
        )

    def run_jj(self, repo: Path | None, *arguments: str) -> str:
        command = ["jj", "--no-pager", "--color=never"]
        if repo is not None:
            command.extend(("-R", str(repo)))
        command.extend(arguments)
        process = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
        )
        if process.returncode != 0:
            self.fail(
                f"{' '.join(command)} failed:\n{process.stdout}\n{process.stderr}"
            )
        return process.stdout

    def revision(self, repo: Path, revset: str) -> str:
        return nixos_config_agent.one_revision(repo, revset, revset)

    def initialize(self) -> str:
        return nixos_config_agent.initialize(
            self.protected,
            self.candidate,
            check_profile=False,
        )

    # These integration fixtures supply confirmation/review callbacks instead
    # of a live terminal. AppArmor entry validation has its own unit test.
    def promote(self, *, confirm, review_diff=lambda *_: None) -> str:
        return nixos_config_agent.promote(
            self.protected,
            self.candidate,
            confirm=confirm,
            output=io.StringIO(),
            review_diff=review_diff,
            check_profile=False,
            require_tty=False,
        )

    def push(self, *, confirm, review_diff=lambda *_: None, candidate=None) -> str:
        return nixos_config_agent.push(
            self.protected,
            self.candidate if candidate is None else candidate,
            confirm=confirm,
            output=io.StringIO(),
            review_diff=review_diff,
            check_profile=False,
            require_tty=False,
        )

    def fetch_updates(self, *, output=None) -> tuple[str, str]:
        return nixos_config_agent.fetch_updates(
            self.protected,
            self.candidate,
            output=io.StringIO() if output is None else output,
            check_profile=False,
        )

    def describe_candidate(self, subject: str = "fix(apparmor): tighten policy") -> str:
        (self.candidate / "configuration.nix").write_text(
            "candidate\n", encoding="utf-8"
        )
        self.run_jj(self.candidate, "describe", "-m", subject)
        return self.revision(self.candidate, "@")

    def promote_candidate(self) -> str:
        candidate_id = self.describe_candidate()
        return self.promote(confirm=lambda _: candidate_id)

    def confirm_id_from_prompt(self, prompt: str) -> str:
        match = re.search(r"[0-9a-f]{40,64}", prompt)
        self.assertIsNotNone(match)
        assert match is not None
        return match.group(0)

    def create_github_change(
        self,
        *,
        path: str = "upstream.txt",
        content: str = "from GitHub\n",
    ) -> str:
        upstream = self.root / "upstream"
        self.run_jj(
            None,
            "git",
            "clone",
            "--colocate",
            "--branch",
            nixos_config_agent.MAIN_BOOKMARK,
            str(self.github),
            str(upstream),
        )
        (upstream / path).write_text(content, encoding="utf-8")
        self.run_jj(upstream, "describe", "-m", "fix: update upstream")
        target = self.revision(upstream, "@")
        self.run_jj(upstream, "bookmark", "track", "main@origin")
        self.run_jj(
            upstream,
            "bookmark",
            "set",
            "-r",
            target,
            nixos_config_agent.MAIN_BOOKMARK,
        )
        self.run_jj(
            upstream,
            "--config",
            "git.sign-on-push=false",
            "git",
            "push",
            "--remote",
            nixos_config_agent.UPSTREAM_REMOTE,
            "--bookmark",
            f"exact:{nixos_config_agent.MAIN_BOOKMARK}",
        )
        return target

    def test_initializes_exact_baseline_and_promotes_one_reviewed_change(self) -> None:
        baseline = self.initialize()
        self.assertTrue(nixos_config_agent.is_empty(self.candidate))
        self.assertEqual(self.revision(self.candidate, "parents(@)"), baseline)
        remotes = nixos_config_agent.remote_urls(self.candidate)
        self.assertEqual(
            remotes[nixos_config_agent.UPSTREAM_REMOTE], str(self.protected)
        )
        self.assertEqual(
            remotes[nixos_config_agent.CANDIDATE_UPSTREAM_REMOTE], str(self.github)
        )
        candidate_id = self.describe_candidate()
        reviews: list[tuple[Path, str, str]] = []

        promoted = self.promote(
            confirm=lambda _: candidate_id,
            review_diff=lambda *arguments: reviews.append(arguments),
        )

        self.assertEqual(promoted, candidate_id)
        self.assertEqual(reviews, [(self.protected, baseline, candidate_id)])
        self.assertEqual(
            (self.protected / "configuration.nix").read_text(encoding="utf-8"),
            "candidate\n",
        )
        self.assertTrue(nixos_config_agent.is_empty(self.protected))
        self.assertTrue(nixos_config_agent.is_empty(self.candidate))
        self.assertEqual(self.revision(self.protected, "parents(@)"), candidate_id)
        self.assertEqual(self.revision(self.candidate, "parents(@)"), candidate_id)

    def test_fetch_advances_main_and_rebases_active_candidate(self) -> None:
        self.initialize()
        candidate_current = self.describe_candidate("fix: keep active candidate")
        candidate_change = nixos_config_agent.revision_value(
            self.candidate, "@", "change_id"
        )
        upstream_target = self.create_github_change()
        output = io.StringIO()

        protected_remote, candidate_remote = self.fetch_updates(output=output)

        self.assertEqual(protected_remote, upstream_target)
        self.assertEqual(candidate_remote, upstream_target)
        self.assertEqual(self.revision(self.protected, "main"), upstream_target)
        self.assertEqual(self.revision(self.protected, "parents(@)"), upstream_target)
        self.assertNotEqual(self.revision(self.candidate, "@"), candidate_current)
        self.assertEqual(
            nixos_config_agent.revision_value(self.candidate, "@", "change_id"),
            candidate_change,
        )
        self.assertEqual(self.revision(self.candidate, "parents(@)"), upstream_target)
        self.assertFalse(nixos_config_agent.is_empty(self.candidate))
        self.assertEqual(self.revision(self.protected, "agent-base"), upstream_target)
        self.assertEqual(self.revision(self.candidate, "agent-base"), upstream_target)
        self.assertEqual(
            self.revision(self.candidate, "agent-handoff"), upstream_target
        )
        self.assertTrue((self.protected / "upstream.txt").is_file())
        self.assertTrue((self.candidate / "upstream.txt").is_file())
        self.assertIn("advanced and local work was rebased", output.getvalue())

    def test_fetch_rebases_promoted_baseline_in_both_clones(self) -> None:
        self.initialize()
        promoted = self.promote_candidate()
        promoted_change = nixos_config_agent.revision_value(
            self.protected, promoted, "change_id"
        )
        upstream_target = self.create_github_change()

        self.fetch_updates()

        protected_baseline = self.revision(self.protected, "parents(@)")
        candidate_baseline = self.revision(self.candidate, "parents(@)")
        self.assertNotEqual(protected_baseline, promoted)
        self.assertEqual(candidate_baseline, protected_baseline)
        self.assertEqual(
            nixos_config_agent.revision_value(
                self.protected, protected_baseline, "change_id"
            ),
            promoted_change,
        )
        self.assertEqual(
            self.revision(self.protected, f"parents({protected_baseline})"),
            upstream_target,
        )
        self.assertEqual(self.revision(self.protected, "main"), upstream_target)
        self.assertEqual(
            self.revision(self.candidate, "agent-base"), protected_baseline
        )
        self.assertEqual(
            self.revision(self.candidate, "agent-handoff"), protected_baseline
        )
        self.assertTrue(nixos_config_agent.is_empty(self.protected))
        self.assertTrue(nixos_config_agent.is_empty(self.candidate))
        self.assertTrue((self.protected / "upstream.txt").is_file())
        self.assertTrue((self.candidate / "upstream.txt").is_file())

    def test_fetch_without_upstream_change_does_not_rewrite_work(self) -> None:
        baseline = self.initialize()
        protected_current = self.revision(self.protected, "@")
        candidate_current = self.describe_candidate()
        output = io.StringIO()

        self.fetch_updates(output=output)

        self.assertEqual(self.revision(self.protected, "@"), protected_current)
        self.assertEqual(self.revision(self.protected, "parents(@)"), baseline)
        self.assertEqual(self.revision(self.candidate, "@"), candidate_current)
        self.assertEqual(self.revision(self.candidate, "parents(@)"), baseline)
        self.assertIn("already contains GitHub main", output.getvalue())

    def test_fetch_leaves_locally_ahead_main_unchanged(self) -> None:
        (self.protected / "local.txt").write_text("local\n", encoding="utf-8")
        self.run_jj(self.protected, "describe", "-m", "fix: keep local main")
        local_main = self.revision(self.protected, "@")
        self.run_jj(
            self.protected,
            "bookmark",
            "set",
            "-r",
            local_main,
            nixos_config_agent.MAIN_BOOKMARK,
        )
        self.run_jj(self.protected, "new", "-m", "")
        self.initialize()
        protected_current = self.revision(self.protected, "@")
        candidate_current = self.revision(self.candidate, "@")

        self.fetch_updates()

        self.assertEqual(self.revision(self.protected, "main"), local_main)
        self.assertEqual(self.revision(self.protected, "@"), protected_current)
        self.assertEqual(self.revision(self.candidate, "@"), candidate_current)

    def test_fetch_refuses_divergent_main_without_moving_local_state(self) -> None:
        (self.protected / "local.txt").write_text("local\n", encoding="utf-8")
        self.run_jj(self.protected, "describe", "-m", "fix: diverge local main")
        local_main = self.revision(self.protected, "@")
        self.run_jj(
            self.protected,
            "bookmark",
            "set",
            "-r",
            local_main,
            nixos_config_agent.MAIN_BOOKMARK,
        )
        self.run_jj(self.protected, "new", "-m", "")
        self.initialize()
        protected_current = self.revision(self.protected, "@")
        candidate_current = self.revision(self.candidate, "@")
        upstream_target = self.create_github_change()

        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "diverged"):
            self.fetch_updates()

        self.assertEqual(self.revision(self.protected, "main"), local_main)
        self.assertEqual(self.revision(self.protected, "@"), protected_current)
        self.assertEqual(self.revision(self.candidate, "@"), candidate_current)
        self.assertEqual(self.revision(self.protected, "main@origin"), upstream_target)
        self.assertEqual(self.revision(self.candidate, "main@github"), upstream_target)

    def test_fetch_rolls_back_protected_rebase_conflict(self) -> None:
        self.initialize()
        promoted = self.promote_candidate()
        protected_current = self.revision(self.protected, "@")
        candidate_current = self.revision(self.candidate, "@")
        local_main = self.revision(self.protected, "main")
        upstream_target = self.create_github_change(
            path="configuration.nix", content="upstream\n"
        )

        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "conflict"):
            self.fetch_updates()

        self.assertEqual(self.revision(self.protected, "main"), local_main)
        self.assertEqual(self.revision(self.protected, "@"), protected_current)
        self.assertEqual(self.revision(self.protected, "parents(@)"), promoted)
        self.assertEqual(self.revision(self.candidate, "@"), candidate_current)
        self.assertEqual(self.revision(self.candidate, "parents(@)"), promoted)
        self.assertFalse(nixos_config_agent.has_conflicts(self.protected))
        self.assertFalse(nixos_config_agent.has_conflicts(self.candidate))
        self.assertEqual(self.revision(self.protected, "main@origin"), upstream_target)
        self.assertEqual(self.revision(self.candidate, "main@github"), upstream_target)

    def test_fetch_rolls_back_candidate_rebase_conflict(self) -> None:
        baseline = self.initialize()
        candidate_current = self.describe_candidate()
        protected_current = self.revision(self.protected, "@")
        local_main = self.revision(self.protected, "main")
        upstream_target = self.create_github_change(
            path="configuration.nix", content="upstream\n"
        )

        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "conflict"):
            self.fetch_updates()

        self.assertEqual(self.revision(self.protected, "main"), local_main)
        self.assertEqual(self.revision(self.protected, "@"), protected_current)
        self.assertEqual(self.revision(self.protected, "parents(@)"), baseline)
        self.assertEqual(self.revision(self.candidate, "@"), candidate_current)
        self.assertEqual(self.revision(self.candidate, "parents(@)"), baseline)
        self.assertFalse(nixos_config_agent.has_conflicts(self.protected))
        self.assertFalse(nixos_config_agent.has_conflicts(self.candidate))
        self.assertEqual(self.revision(self.protected, "main@origin"), upstream_target)
        self.assertEqual(self.revision(self.candidate, "main@github"), upstream_target)

    def test_failed_second_fetch_restores_protected_main(self) -> None:
        self.initialize()
        protected_main = self.revision(self.protected, "main")
        self.create_github_change()
        real_fetch_main = nixos_config_agent.fetch_main

        def fail_candidate_fetch(repo: Path, remote: str) -> str:
            if repo == self.candidate:
                raise nixos_config_agent.WorkflowError("candidate fetch failed")
            return real_fetch_main(repo, remote)

        with (
            mock.patch.object(
                nixos_config_agent, "fetch_main", side_effect=fail_candidate_fetch
            ),
            self.assertRaisesRegex(
                nixos_config_agent.WorkflowError, "candidate fetch failed"
            ),
        ):
            self.fetch_updates()

        self.assertEqual(self.revision(self.protected, "main"), protected_main)

    def test_push_signs_publishes_and_rebases_candidate(self) -> None:
        remote_before = self.revision(self.protected, "main@origin")
        self.initialize()
        promoted = self.promote_candidate()
        reviews: list[tuple[Path, str, str]] = []

        published = self.push(
            confirm=self.confirm_id_from_prompt,
            review_diff=lambda *arguments: reviews.append(arguments),
        )

        self.assertNotEqual(published, promoted)
        self.assertEqual(reviews, [(self.protected, remote_before, published)])
        self.assertEqual(self.revision(self.protected, "main"), published)
        self.assertEqual(self.revision(self.protected, "main@origin"), published)
        self.assertEqual(self.revision(self.protected, "parents(@)"), published)
        self.assertEqual(self.revision(self.candidate, "main@github"), published)
        self.assertEqual(self.revision(self.candidate, "parents(@)"), published)
        self.assertEqual(self.revision(self.candidate, "agent-base"), published)
        self.assertEqual(
            self.revision(self.candidate, "agent-base@origin"), published
        )
        self.assertEqual(self.revision(self.candidate, "agent-handoff"), published)
        self.assertTrue(nixos_config_agent.is_empty(self.protected))
        self.assertTrue(nixos_config_agent.is_empty(self.candidate))
        self.assertEqual(
            self.revision(self.protected, f"({published}) & signed()"), published
        )
        self.assertEqual(
            nixos_config_agent.revision_ids(self.candidate, "divergent()"), []
        )
        self.assertEqual(
            nixos_config_agent.revision_ids(self.candidate, "visible_heads()"),
            [self.revision(self.candidate, "@")],
        )

    def test_push_rebases_promoted_work_when_github_advanced(self) -> None:
        self.initialize()
        promoted = self.promote_candidate()
        promoted_change = nixos_config_agent.revision_value(
            self.protected, promoted, "change_id"
        )
        upstream_target = self.create_github_change()
        reviews: list[tuple[Path, str, str]] = []

        published = self.push(
            confirm=self.confirm_id_from_prompt,
            review_diff=lambda *arguments: reviews.append(arguments),
        )

        self.assertEqual(reviews, [(self.protected, upstream_target, published)])
        self.assertEqual(
            nixos_config_agent.revision_value(self.protected, published, "change_id"),
            promoted_change,
        )
        self.assertEqual(self.revision(self.protected, "main"), published)
        self.assertEqual(self.revision(self.protected, "main@origin"), published)
        self.assertEqual(self.revision(self.protected, "parents(@)"), published)
        self.assertEqual(self.revision(self.candidate, "main@github"), published)
        self.assertEqual(self.revision(self.candidate, "parents(@)"), published)
        self.assertTrue((self.protected / "upstream.txt").is_file())
        self.assertTrue((self.candidate / "upstream.txt").is_file())

    def test_rejected_push_restores_main_and_realigns_signed_baseline(self) -> None:
        remote_before = self.revision(self.protected, "main@origin")
        self.initialize()
        promoted = self.promote_candidate()
        self.config.write_text(
            self.config.read_text(encoding="utf-8").replace(
                'signing.behavior = "drop"', 'signing.behavior = "own"'
            ),
            encoding="utf-8",
        )

        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "did not match"):
            self.push(confirm=lambda _: "no")

        signed_baseline = self.revision(self.protected, "parents(@)")
        self.assertNotEqual(signed_baseline, promoted)
        self.assertEqual(self.revision(self.protected, "main"), remote_before)
        self.assertEqual(self.revision(self.protected, "main@origin"), remote_before)
        self.assertEqual(self.revision(self.candidate, "parents(@)"), signed_baseline)
        self.assertEqual(self.revision(self.candidate, "agent-base"), signed_baseline)
        self.assertTrue(nixos_config_agent.is_empty(self.protected))
        self.assertTrue(nixos_config_agent.is_empty(self.candidate))

    def test_push_refuses_active_candidate_and_nonconventional_history(self) -> None:
        self.initialize()
        self.describe_candidate()
        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "must be empty"):
            self.push(confirm=lambda _: "")

        other_candidate = self.root / "other-writable"
        (self.protected / "bad.txt").write_text("bad subject\n", encoding="utf-8")
        self.run_jj(self.protected, "describe", "-m", "not conventional")
        self.run_jj(self.protected, "new", "-m", "")
        nixos_config_agent.initialize(
            self.protected,
            other_candidate,
            check_profile=False,
        )
        with self.assertRaisesRegex(
            nixos_config_agent.WorkflowError, "Conventional Commit"
        ):
            self.push(confirm=lambda _: "", candidate=other_candidate)

    def test_push_refuses_divergent_main(self) -> None:
        self.initialize()
        self.promote_candidate()
        protected_current = self.revision(self.protected, "@")
        self.run_jj(
            self.protected,
            "new",
            "root()",
            "-m",
            "fix: create divergent main",
        )
        divergent_main = self.revision(self.protected, "@")
        self.run_jj(
            self.protected,
            "bookmark",
            "set",
            "--allow-backwards",
            "-r",
            divergent_main,
            nixos_config_agent.MAIN_BOOKMARK,
        )
        self.run_jj(self.protected, "edit", protected_current)

        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "diverged"):
            self.push(confirm=lambda _: "")

    def test_refuses_existing_destination(self) -> None:
        self.candidate.mkdir()
        with self.assertRaisesRegex(
            nixos_config_agent.WorkflowError, "destination already exists"
        ):
            self.initialize()

    def test_refuses_empty_or_nonconventional_candidate(self) -> None:
        self.initialize()
        with self.assertRaisesRegex(
            nixos_config_agent.WorkflowError, "change is empty"
        ):
            self.promote(confirm=lambda _: "")

        self.describe_candidate("not a conventional subject")
        with self.assertRaisesRegex(
            nixos_config_agent.WorkflowError, "Conventional Commit"
        ):
            self.promote(confirm=lambda _: "")

    def test_rejection_and_stale_baseline_leave_protected_tree_unchanged(self) -> None:
        self.initialize()
        candidate_id = self.describe_candidate()
        protected_before = self.revision(self.protected, "@")
        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "did not match"):
            self.promote(confirm=lambda _: "no")
        self.assertEqual(self.revision(self.protected, "@"), protected_before)

        (self.protected / "configuration.nix").write_text(
            "new baseline\n", encoding="utf-8"
        )
        self.run_jj(self.protected, "describe", "-m", "fix: advance protected")
        self.run_jj(self.protected, "new", "-m", "")
        stale_protected = self.revision(self.protected, "@")
        with self.assertRaisesRegex(nixos_config_agent.WorkflowError, "does not match"):
            self.promote(confirm=lambda _: candidate_id)
        self.assertEqual(self.revision(self.protected, "@"), stale_protected)


class NixosConfigAgentUnitTest(unittest.TestCase):
    def test_display_diff_uses_the_configured_jj_pager(self) -> None:
        diff = subprocess.CompletedProcess(
            [], 0, stdout="diff --git a/file b/file\n", stderr=""
        )
        review = subprocess.CompletedProcess([], 0)
        with (
            mock.patch.object(
                nixos_config_agent,
                "run_jj",
                return_value='["delta", "--side-by-side"]',
            ),
            mock.patch.object(
                nixos_config_agent.subprocess,
                "run",
                side_effect=(diff, review),
            ) as run,
        ):
            nixos_config_agent.display_diff(
                Path("/review-repository"), "from-id", "to-id"
            )

        diff_call, pager_call = run.call_args_list
        command = diff_call.args[0]
        self.assertEqual(command[:3], ["jj", "--no-pager", "--color=never"])
        self.assertEqual(command[-5:], ["--git", "--from", "from-id", "--to", "to-id"])
        self.assertEqual(pager_call.args[0], ["delta", "--side-by-side"])
        self.assertEqual(pager_call.kwargs["input"], diff.stdout)

    def test_requires_unconfined_label(self) -> None:
        with self.assertRaisesRegex(
            nixos_config_agent.WorkflowError, "must run unconfined"
        ):
            nixos_config_agent.require_unconfined(lambda: "local-codex-cli (complain)")


if __name__ == "__main__":
    unittest.main()

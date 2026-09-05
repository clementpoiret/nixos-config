from __future__ import annotations

import datetime as dt
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SOURCE = Path(
    os.environ.get(
        "APPARMOR_REPORT_SOURCE",
        Path(__file__).parents[1] / "modules/core/apparmor_report.py",
    )
)
SPEC = importlib.util.spec_from_file_location("apparmor_report", SOURCE)
assert SPEC is not None and SPEC.loader is not None
apparmor_report = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = apparmor_report
SPEC.loader.exec_module(apparmor_report)


class AppArmorReportTest(unittest.TestCase):
    def test_accepts_archive_boot_ids_and_preserves_signed_offsets(self) -> None:
        parser = apparmor_report.build_parser()
        self.assertEqual(
            parser.parse_args(["--boot", "12a90c1d-74a4-4405-9565-b5aa12c79fbc"]).boot,
            "12a90c1d74a444059565b5aa12c79fbc",
        )
        self.assertEqual(parser.parse_args(["--boot", "-1"]).boot, "-1")

    @staticmethod
    def journal_record(message: str, transport: str, boot: str = "boot-a") -> str:
        entry = {"MESSAGE": message, "_TRANSPORT": transport, "_BOOT_ID": boot}
        if transport == "audit":
            entry["_AUDIT_ID"] = "42"
        return json.dumps(entry)

    def test_queries_audit_and_kernel_transports_with_delivery_warnings(self) -> None:
        args = mock.Mock(boot="-1", since="yesterday", until="today")
        with (
            mock.patch.object(
                apparmor_report.shutil, "which", return_value="journalctl"
            ),
            mock.patch.object(
                apparmor_report, "_stream_command", return_value=iter([])
            ) as stream,
        ):
            self.assertEqual(list(apparmor_report.journal_lines(args)), [])
        command = stream.call_args.args[0]
        self.assertIn("--boot=-1", command)
        self.assertIn("_TRANSPORT=audit", command)
        self.assertIn("_TRANSPORT=kernel", command)
        self.assertIn("kauditd_printk_skb", command[command.index("--grep") + 1])
        self.assertEqual(command[-4:], ["--since", "yesterday", "--until", "today"])

    def test_deduplicates_transports_without_losing_stacked_or_kernel_only_records(
        self,
    ) -> None:
        message = (
            'apparmor="ALLOWED" operation="open" class="file" profile="local-test" '
            'name="/tmp/example" pid=12 comm="cat" requested_mask="r" denied_mask="r"'
        )
        audit = self.journal_record("AVC " + message, "audit")
        kernel = self.journal_record(
            "audit: type=1400 audit(1.0:42): " + message, "kernel"
        )
        stacked = self.journal_record(
            "AVC "
            + message.replace('profile="local-test"', 'profile="local-test//child"'),
            "audit",
        )
        kernel_only = self.journal_record(
            "audit: type=1400 audit(1.0:43): " + message, "kernel"
        )
        other_boot = self.journal_record("AVC " + message, "audit", "boot-b")
        for copies in ([audit, kernel], [kernel, audit]):
            with self.subTest(order=copies):
                lines = list(
                    apparmor_report.deduplicate_journal_lines(
                        [*copies, stacked, kernel_only, other_boot]
                    )
                )
                self.assertEqual(lines, [copies[0], stacked, kernel_only, other_boot])

    def test_retains_repeated_raw_records_without_audit_identity(self) -> None:
        raw = 'apparmor="DENIED" profile="local-test" name="/tmp/example"'
        journal = json.dumps({"MESSAGE": raw})
        lines = [raw, raw, journal, journal]
        self.assertEqual(list(apparmor_report.deduplicate_journal_lines(lines)), lines)

    def test_reports_audit_delivery_failures_independently_of_profile_filter(
        self,
    ) -> None:
        for message in (
            "kauditd_printk_skb: 17262 callbacks suppressed",
            "audit: audit_lost=42 audit_rate_limit=0 audit_backlog_limit=64",
            "audit: backlog limit exceeded",
            "audit: rate limit exceeded",
        ):
            with self.subTest(message=message):
                issue = apparmor_report.parse_kernel_issue(message, ["local-test"])
                self.assertIsNotNone(issue)
                self.assertEqual(issue["message"], message)
        self.assertIsNone(
            apparmor_report.parse_kernel_issue("audit: audit_lost=0", ["*"])
        )

    def test_journal_lines_treats_no_grep_matches_as_empty(self) -> None:
        process = mock.Mock(
            stdout=io.StringIO(""),
            stderr=io.StringIO(""),
        )
        process.wait.return_value = 1
        args = mock.Mock(boot="0", since=None, until=None)
        with (
            mock.patch.object(
                apparmor_report.shutil, "which", return_value="/bin/journalctl"
            ),
            mock.patch.object(
                apparmor_report.subprocess, "Popen", return_value=process
            ),
        ):
            lines = list(apparmor_report.journal_lines(args))

        self.assertEqual(lines, [])

    def test_journal_lines_preserves_journalctl_errors(self) -> None:
        process = mock.Mock(
            stdout=io.StringIO(""),
            stderr=io.StringIO("permission denied\n"),
        )
        process.wait.return_value = 1
        args = mock.Mock(boot="0", since=None, until=None)
        with (
            mock.patch.object(
                apparmor_report.shutil, "which", return_value="/bin/journalctl"
            ),
            mock.patch.object(
                apparmor_report.subprocess, "Popen", return_value=process
            ),
            self.assertRaisesRegex(RuntimeError, "permission denied"),
        ):
            list(apparmor_report.journal_lines(args))

    def test_parses_quoted_fields_and_owner_relationship(self) -> None:
        event = apparmor_report.parse_policy_event(
            'audit: type=1400 audit(1786960144.030:4979): apparmor="ALLOWED" '
            'operation="open" class="file" profile="local-brave" '
            'name="/home/test/file with spaces" pid=12 comm="brave" '
            'requested_mask="r" denied_mask="r" fsuid=1000 ouid=1000',
            ["local-*"],
        )

        self.assertIsNotNone(event)
        assert event is not None
        self.assertEqual(event.result, "ALLOWED")
        self.assertEqual(event.targets, (("name", "/home/test/file with spaces"),))
        self.assertIn(("owner_match", "yes"), event.details)
        self.assertIn(("fsuid", "1000"), event.details)
        assert event.timestamp is not None
        self.assertEqual(
            dt.datetime.fromisoformat(event.timestamp).timestamp(), 1786960144
        )

    def test_decodes_hex_encoded_comm_and_collapses_null_profile(self) -> None:
        event = apparmor_report.parse_policy_event(
            'audit: type=1400 audit(1.0:1): apparmor="ALLOWED" operation="open" '
            'class="file" profile="local-brave//null-/nix/store/example" '
            'name="/tmp/example" comm=5B50616E676F5D20666F6E74636F6E '
            'requested_mask="r" denied_mask="r" fsuid=1000 ouid=0',
            ["local-brave"],
        )

        self.assertIsNotNone(event)
        assert event is not None
        self.assertEqual(event.profile, "local-brave")
        self.assertTrue(event.null_profile)
        self.assertEqual(event.command, "[Pango] fontcon")
        self.assertIn(("owner_match", "no"), event.details)

    def test_aggregates_operations_that_need_the_same_rule(self) -> None:
        messages = [
            (
                'apparmor="ALLOWED" operation="open" class="file" profile="local-brave" '
                'name="/tmp/example" comm="brave" requested_mask="r" denied_mask="r"'
            ),
            (
                'apparmor="ALLOWED" operation="getattr" class="file" profile="local-brave" '
                'name="/tmp/example" comm="worker" requested_mask="r" denied_mask="r"'
            ),
        ]
        events = [
            apparmor_report.parse_policy_event(message, ["local-*"])
            for message in messages
        ]
        findings = apparmor_report.aggregate(
            event for event in events if event is not None
        )

        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].count, 2)
        self.assertEqual(findings[0].operations, {"getattr", "open"})
        self.assertEqual(findings[0].commands, {"brave", "worker"})

    def test_parses_and_prioritizes_explicit_audit_records(self) -> None:
        audit_event = apparmor_report.parse_policy_event(
            'apparmor="AUDIT" operation="open" class="file" profile="local-codex-cli" '
            'name="/home/test/nixos-config/flake.nix" requested_mask="w" denied_mask="w"',
            ["local-*"],
        )
        allowed_event = apparmor_report.parse_policy_event(
            'apparmor="ALLOWED" operation="open" class="file" profile="local-codex-cli" '
            'name="/tmp/example" requested_mask="r" denied_mask="r"',
            ["local-*"],
        )

        self.assertIsNotNone(audit_event)
        assert audit_event is not None
        self.assertEqual(audit_event.result, "AUDIT")
        findings = apparmor_report.aggregate(
            event for event in (allowed_event, audit_event) if event is not None
        )
        self.assertEqual([finding.result for finding in findings], ["AUDIT", "ALLOWED"])

    def test_filters_unmanaged_profiles_and_normal_status_records(self) -> None:
        self.assertIsNone(
            apparmor_report.parse_policy_event(
                'apparmor="DENIED" operation="open" class="file" '
                'profile="upstream-profile" name="/tmp/example"',
                ["local-*"],
            )
        )
        self.assertIsNone(
            apparmor_report.parse_kernel_issue(
                'apparmor="STATUS" operation="profile_load" profile="unconfined" '
                'name="local-brave"',
                ["local-*"],
            )
        )
        self.assertIsNone(
            apparmor_report.parse_policy_event(
                'apparmor="STATUS" operation="profile_replace" '
                'profile="unconfined" name="local-brave"',
                ["*"],
            )
        )

    def test_keeps_local_kernel_errors(self) -> None:
        issue = apparmor_report.parse_kernel_issue(
            'apparmor="ERROR" operation="profile_load" profile="unconfined" '
            'name="local-brave" info="policy error"',
            ["local-*"],
        )

        self.assertIsNotNone(issue)
        assert issue is not None
        self.assertIn('apparmor="ERROR"', issue["message"])

    def test_parses_journal_json_timestamp(self) -> None:
        message, timestamp = apparmor_report.unpack_input_line(
            '{"MESSAGE":"example","__REALTIME_TIMESTAMP":"1786960144030000"}'
        )

        self.assertEqual(message, "example")
        assert timestamp is not None
        self.assertEqual(dt.datetime.fromisoformat(timestamp).timestamp(), 1786960144)

    def test_prefers_audit_event_timestamp_to_journal_receipt_time(self) -> None:
        _, timestamp = apparmor_report.unpack_input_line(
            json.dumps(
                {
                    "MESSAGE": "example",
                    "_SOURCE_REALTIME_TIMESTAMP": "1786960144030000",
                    "__REALTIME_TIMESTAMP": "1786960154030000",
                }
            )
        )
        self.assertEqual(dt.datetime.fromisoformat(timestamp).timestamp(), 1786960144)

    def test_extracts_and_collapses_aa_status_profile_modes(self) -> None:
        modes = apparmor_report.extract_profile_modes(
            {
                "profiles": {
                    "local-brave": "complain",
                    "local-brave//null-child": "complain",
                    "local-syncthing": "enforce",
                    "unmanaged": "enforce",
                }
            },
            ["local-*"],
        )

        self.assertEqual(
            modes,
            {"local-brave": "complain", "local-syncthing": "enforce"},
        )

    def test_current_profile_modes_applies_globs_without_hardcoded_filter(self) -> None:
        cases = (
            (
                "profiles",
                """print('{"profiles":{"local-brave":"complain","upstream":"enforce"}}')""",
                {"local-brave": "complain", "upstream": "enforce"},
                None,
            ),
            ("command error", 'sys.exit("permission denied")', {}, "permission denied"),
        )
        for name, response, expected_modes, expected_error in cases:
            with self.subTest(case=name), tempfile.TemporaryDirectory() as temporary:
                aa_status = Path(temporary) / "aa-status"
                aa_status.write_text(
                    f"#!{sys.executable}\n"
                    "import sys\n"
                    "if sys.argv[1:] != ['--json']:\n"
                    "    sys.exit('expected --json')\n"
                    f"{response}\n",
                    encoding="utf-8",
                )
                aa_status.chmod(0o755)
                with mock.patch.object(
                    apparmor_report.shutil, "which", return_value=str(aa_status)
                ):
                    modes, error = apparmor_report.current_profile_modes(["*"])

                self.assertEqual(error, expected_error)
                self.assertEqual(modes, expected_modes)


if __name__ == "__main__":
    unittest.main()

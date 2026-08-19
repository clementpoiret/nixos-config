from __future__ import annotations

import datetime as dt
import importlib.util
import os
import sys
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
        process = mock.Mock(
            returncode=0,
            stdout='{"profiles":{"local-brave":"complain","upstream":"enforce"}}',
            stderr="",
        )
        with (
            mock.patch.object(
                apparmor_report.shutil, "which", return_value="/bin/aa-status"
            ),
            mock.patch.object(
                apparmor_report.subprocess, "run", return_value=process
            ) as run,
        ):
            modes, error = apparmor_report.current_profile_modes(["*"])

        self.assertIsNone(error)
        self.assertEqual(modes, {"local-brave": "complain", "upstream": "enforce"})
        run.assert_called_once_with(
            ["/bin/aa-status", "--json"],
            capture_output=True,
            text=True,
            check=False,
        )


if __name__ == "__main__":
    unittest.main()

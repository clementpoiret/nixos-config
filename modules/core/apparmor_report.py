"""Summarize local AppArmor policy gaps from journal or saved audit records."""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import fnmatch
import json
import re
import shutil
import subprocess
import sys
from collections.abc import Iterable, Iterator
from dataclasses import dataclass, field
from pathlib import Path

FIELD_RE = re.compile(r'\b([A-Za-z_][A-Za-z0-9_]*)=(?:"((?:\\.|[^"\\])*)"|(\S+))')
AUDIT_TIME_RE = re.compile(r"\baudit\((\d+(?:\.\d+)?):")
HEX_RE = re.compile(r"(?:[0-9A-Fa-f]{2})+")
LOAD_ISSUE_RE = re.compile(
    r"\b(error|failed?|failure|warning|unable|invalid|syntax|permission denied)\b",
    re.IGNORECASE,
)

TARGET_FIELDS = (
    "name",
    "name2",
    "srcname",
    "execpath",
    "peer",
    "peer_profile",
    "peer_addr",
)
IGNORED_DETAIL_FIELDS = {
    "apparmor",
    "class",
    "comm",
    "denied",
    "denied_mask",
    "fsuid",
    "operation",
    "ouid",
    "parent",
    "peer_pid",
    "pid",
    "profile",
    "requested",
    "requested_mask",
    "task",
    "type",
    *TARGET_FIELDS,
}
HEX_FIELDS = {
    "comm",
    "execpath",
    "info",
    "name",
    "name2",
    "namespace",
    "peer",
    "peer_addr",
    "peer_profile",
    "profile",
    "srcname",
    "target",
}


@dataclass(frozen=True)
class PolicyEvent:
    result: str
    profile: str
    full_profile: str
    event_class: str
    operation: str
    requested: str
    denied: str
    targets: tuple[tuple[str, str], ...]
    details: tuple[tuple[str, str], ...]
    command: str
    null_profile: bool
    timestamp: str | None
    raw: str


@dataclass
class Finding:
    result: str
    profile: str
    event_class: str
    requested: str
    denied: str
    targets: tuple[tuple[str, str], ...]
    details: tuple[tuple[str, str], ...]
    null_profile: bool
    count: int = 0
    operations: set[str] = field(default_factory=set)
    commands: set[str] = field(default_factory=set)
    first: str | None = None
    last: str | None = None
    sample: str = ""

    def add(self, event: PolicyEvent) -> None:
        self.count += 1
        if event.operation:
            self.operations.add(event.operation)
        if event.command:
            self.commands.add(event.command)
        if event.timestamp:
            if self.first is None or event.timestamp < self.first:
                self.first = event.timestamp
            if self.last is None or event.timestamp > self.last:
                self.last = event.timestamp
        if not self.sample:
            self.sample = event.raw

    def as_dict(self) -> dict[str, object]:
        return {
            "result": self.result,
            "profile": self.profile,
            "class": self.event_class,
            "operations": sorted(self.operations),
            "requested": self.requested or None,
            "denied": self.denied or None,
            "targets": dict(self.targets),
            "details": dict(self.details),
            "null_profile": self.null_profile,
            "count": self.count,
            "commands": sorted(self.commands),
            "first": self.first,
            "last": self.last,
            "sample": self.sample,
        }


def _decode_quoted(value: str) -> str:
    return re.sub(r"\\([\\\"])", r"\1", value)


def _decode_hex(field_name: str, value: str, quoted: bool) -> str:
    if quoted or field_name not in HEX_FIELDS or not HEX_RE.fullmatch(value):
        return value
    try:
        decoded = bytes.fromhex(value).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        return value
    if decoded.startswith("/") or any(not char.isalnum() for char in decoded):
        return decoded
    return value


def parse_fields(message: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for match in FIELD_RE.finditer(message):
        name = match.group(1)
        quoted = match.group(2) is not None
        value = match.group(2) if quoted else match.group(3)
        assert value is not None
        if quoted:
            value = _decode_quoted(value)
        fields[name] = _decode_hex(name, value, quoted)
    return fields


def _timestamp_from_epoch(epoch: str | int | None) -> str | None:
    if epoch is None:
        return None
    try:
        seconds = float(epoch)
        if seconds > 10_000_000_000:
            seconds /= 1_000_000
        return (
            dt.datetime.fromtimestamp(seconds)
            .astimezone()
            .isoformat(timespec="seconds")
        )
    except (OSError, OverflowError, ValueError):
        return None


def unpack_input_line(line: str) -> tuple[str, str | None]:
    stripped = line.strip()
    if not stripped:
        return "", None
    if stripped.startswith("{"):
        try:
            entry = json.loads(stripped)
        except json.JSONDecodeError:
            pass
        else:
            message = entry.get("MESSAGE", "")
            timestamp = _timestamp_from_epoch(entry.get("__REALTIME_TIMESTAMP"))
            return str(message), timestamp
    audit_time = AUDIT_TIME_RE.search(stripped)
    return stripped, _timestamp_from_epoch(audit_time.group(1)) if audit_time else None


def _matches_profile(profile: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(profile, pattern) for pattern in patterns)


def parse_policy_event(line: str, patterns: list[str]) -> PolicyEvent | None:
    message, timestamp = unpack_input_line(line)
    if not message:
        return None
    fields = parse_fields(message)
    result = fields.get("apparmor", "")
    if result not in {"ALLOWED", "AUDIT", "DENIED"}:
        return None

    full_profile = fields.get("profile", "")
    profile = full_profile.split("//", 1)[0]
    if not profile or not _matches_profile(profile, patterns):
        return None

    requested = fields.get("requested_mask", fields.get("requested", ""))
    denied = fields.get("denied_mask", fields.get("denied", ""))
    targets = tuple((name, fields[name]) for name in TARGET_FIELDS if fields.get(name))

    details = {
        name: value
        for name, value in fields.items()
        if name not in IGNORED_DETAIL_FIELDS
    }
    fsuid = fields.get("fsuid")
    ouid = fields.get("ouid")
    if fsuid is not None and ouid is not None:
        details["owner_match"] = "yes" if fsuid == ouid else "no"

    return PolicyEvent(
        result=result,
        profile=profile,
        full_profile=full_profile,
        event_class=fields.get("class", "unknown"),
        operation=fields.get("operation", "unknown"),
        requested=requested,
        denied=denied,
        targets=targets,
        details=tuple(sorted(details.items())),
        command=fields.get("comm", ""),
        null_profile="//null-" in full_profile,
        timestamp=timestamp,
        raw=message,
    )


def parse_kernel_issue(line: str, patterns: list[str]) -> dict[str, str] | None:
    message, timestamp = unpack_input_line(line)
    if not message:
        return None
    fields = parse_fields(message)
    if fields.get("apparmor") != "ERROR":
        return None
    names = (fields.get("profile", "").split("//", 1)[0], fields.get("name", ""))
    if not any(name and _matches_profile(name, patterns) for name in names):
        return None
    return {"timestamp": timestamp or "unknown", "message": message}


def add_event(grouped: dict[tuple[object, ...], Finding], event: PolicyEvent) -> None:
    key = (
        event.result,
        event.profile,
        event.event_class,
        event.requested,
        event.denied,
        event.targets,
        event.details,
        event.null_profile,
    )
    finding = grouped.get(key)
    if finding is None:
        finding = Finding(
            result=event.result,
            profile=event.profile,
            event_class=event.event_class,
            requested=event.requested,
            denied=event.denied,
            targets=event.targets,
            details=event.details,
            null_profile=event.null_profile,
        )
        grouped[key] = finding
    finding.add(event)


def sorted_findings(grouped: dict[tuple[object, ...], Finding]) -> list[Finding]:
    return sorted(
        grouped.values(),
        key=lambda item: (
            {"DENIED": 0, "AUDIT": 1, "ALLOWED": 2}.get(item.result, 3),
            item.profile,
            -item.count,
            item.event_class,
            item.targets,
        ),
    )


def aggregate(events: Iterable[PolicyEvent]) -> list[Finding]:
    grouped: dict[tuple[object, ...], Finding] = {}
    for event in events:
        add_event(grouped, event)
    return sorted_findings(grouped)


def _stream_command(command: list[str]) -> Iterator[str]:
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    assert process.stdout is not None
    yield from process.stdout
    stderr = process.stderr.read() if process.stderr is not None else ""
    return_code = process.wait()
    if return_code != 0:
        detail = stderr.strip() or f"exit status {return_code}"
        raise RuntimeError(f"{' '.join(command[:2])}: {detail}")


def journal_lines(args: argparse.Namespace) -> Iterator[str]:
    journalctl = shutil.which("journalctl")
    if journalctl is None:
        raise RuntimeError("journalctl is not available")
    command = [
        journalctl,
        "--quiet",
        "--no-pager",
        "--all",
        "--output=json",
        "--boot",
        args.boot,
        "_TRANSPORT=kernel",
        "--grep",
        'apparmor="(ALLOWED|AUDIT|DENIED|ERROR)"',
    ]
    if args.since:
        command.extend(("--since", args.since))
    if args.until:
        command.extend(("--until", args.until))
    yield from _stream_command(command)


def input_lines(path: str) -> Iterator[str]:
    if path == "-":
        yield from sys.stdin
        return
    with Path(path).open(encoding="utf-8") as handle:
        yield from handle


def extract_profile_modes(data: object, patterns: list[str]) -> dict[str, str]:
    modes: dict[str, str] = {}

    def add(profile: str, mode: str) -> None:
        base_profile = profile.split("//", 1)[0]
        if not _matches_profile(base_profile, patterns):
            return
        previous = modes.get(base_profile)
        modes[base_profile] = mode if previous in {None, mode} else "mixed"

    if isinstance(data, dict) and isinstance(data.get("profiles"), dict):
        for profile, mode in data["profiles"].items():
            if isinstance(profile, str) and isinstance(mode, str):
                add(profile, mode)

    def visit(value: object) -> None:
        if isinstance(value, dict):
            profile = value.get("profile") or value.get("name")
            mode = value.get("mode") or value.get("status")
            if isinstance(profile, str) and isinstance(mode, str):
                add(profile, mode)
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    visit(data)
    return dict(sorted(modes.items()))


def current_profile_modes(patterns: list[str]) -> tuple[dict[str, str], str | None]:
    aa_status = shutil.which("aa-status")
    if aa_status is None:
        return {}, "aa-status is not available"
    process = subprocess.run(
        [aa_status, "--json"],
        capture_output=True,
        text=True,
        check=False,
    )
    if process.returncode != 0:
        detail = (
            process.stderr.strip()
            or process.stdout.strip()
            or f"exit status {process.returncode}"
        )
        return {}, detail
    try:
        data = json.loads(process.stdout)
    except json.JSONDecodeError as error:
        return {}, f"could not parse aa-status JSON: {error}"

    return extract_profile_modes(data, patterns), None


def apparmor_service(
    args: argparse.Namespace,
) -> tuple[dict[str, str], list[dict[str, str]], str | None]:
    journalctl = shutil.which("journalctl")
    systemctl = shutil.which("systemctl")
    if journalctl is None or systemctl is None:
        return {}, [], "journalctl or systemctl is not available"

    status: dict[str, str] = {}
    if args.boot == "0":
        process = subprocess.run(
            [
                systemctl,
                "show",
                "apparmor.service",
                "--property=ActiveState",
                "--property=SubState",
                "--property=Result",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if process.returncode == 0:
            status = dict(
                line.split("=", 1)
                for line in process.stdout.splitlines()
                if "=" in line
            )

    command = [
        journalctl,
        "--quiet",
        "--no-pager",
        "--all",
        "--output=json",
        "--boot",
        args.boot,
        "--unit",
        "apparmor.service",
    ]
    if args.since:
        command.extend(("--since", args.since))
    if args.until:
        command.extend(("--until", args.until))

    issues: list[dict[str, str]] = []
    try:
        lines = _stream_command(command)
        for line in lines:
            message, timestamp = unpack_input_line(line)
            if message and LOAD_ISSUE_RE.search(message):
                issues.append({"timestamp": timestamp or "unknown", "message": message})
    except RuntimeError as error:
        return status, issues, str(error)
    return status, issues, None


def _finding_line(finding: Finding) -> str:
    operations = ",".join(sorted(finding.operations)) or "unknown"
    access_parts = []
    if finding.requested:
        access_parts.append(f"requested={finding.requested}")
    if finding.denied:
        access_parts.append(f"denied={finding.denied}")
    targets = " ".join(
        f"{name}={json.dumps(value, ensure_ascii=False)}"
        for name, value in finding.targets
    )
    qualifiers = [
        f"{name}={json.dumps(value, ensure_ascii=False)}"
        for name, value in finding.details
    ]
    if finding.null_profile:
        qualifiers.append("null_profile=yes")
    fields = [
        f"{finding.count:>8}",
        f"{finding.event_class}/{operations}",
        *access_parts,
        targets,
        " ".join(qualifiers),
    ]
    return "  ".join(part for part in fields if part)


def render_text(report: dict[str, object], findings: list[Finding]) -> None:
    summary = report["summary"]
    assert isinstance(summary, dict)
    print("AppArmor policy report")
    print(f"Source: {report['source']}")
    print(f"Profiles: {', '.join(report['profile_patterns'])}")
    print(
        "Events: "
        f"{summary['events']} total; {summary['denied']} blocked; "
        f"{summary['audited']} explicit audit observations; "
        f"{summary['allowed']} complain observations; {summary['groups']} grouped findings"
    )

    profile_modes = report["current_profile_modes"]
    assert isinstance(profile_modes, dict)
    print("\nCurrent loaded profile modes:")
    if profile_modes:
        by_mode: dict[str, list[str]] = collections.defaultdict(list)
        for profile, mode in profile_modes.items():
            by_mode[str(mode)].append(str(profile))
        for mode in sorted(by_mode):
            print(f"  {mode}: {', '.join(sorted(by_mode[mode]))}")
    else:
        print(
            f"  unavailable: {report['profile_status_error'] or 'no matching loaded profiles'}"
        )

    service_status = report["apparmor_service"]
    service_issues = report["service_issues"]
    kernel_issues = report["kernel_issues"]
    assert isinstance(service_status, dict)
    assert isinstance(service_issues, list)
    assert isinstance(kernel_issues, list)
    print("\nPolicy loading:")
    if service_status:
        print(
            "  apparmor.service: "
            f"{service_status.get('ActiveState', 'unknown')}/"
            f"{service_status.get('SubState', 'unknown')}, "
            f"result={service_status.get('Result', 'unknown')}"
        )
    for issue in [*service_issues, *kernel_issues]:
        print(f"  {issue['timestamp']}  {issue['message']}")
    if not service_issues and not kernel_issues and not report["service_status_error"]:
        print("  no load errors found")
    elif report["service_status_error"]:
        print(f"  status unavailable: {report['service_status_error']}")

    headings = {
        "DENIED": "Blocked accesses (enforce-mode decisions or explicit deny rules)",
        "AUDIT": "Explicitly audited allowed accesses",
        "ALLOWED": "Complain-mode observations (would be blocked in enforce mode)",
    }
    for result in ("DENIED", "AUDIT", "ALLOWED"):
        selected = [finding for finding in findings if finding.result == result]
        print(f"\n{headings[result]}:")
        if not selected:
            print("  none")
            continue
        current_profile = None
        for finding in selected:
            if finding.profile != current_profile:
                current_profile = finding.profile
                print(f"\n  [{current_profile}]")
            print(f"  {_finding_line(finding)}")
            if finding.commands:
                print(f"           commands={','.join(sorted(finding.commands))}")
            if finding.first:
                interval = (
                    finding.first
                    if finding.first == finding.last
                    else f"{finding.first} .. {finding.last}"
                )
                print(f"           seen={interval}")

    print(
        "\nReview each observation against an intentional workload before adding a rule. "
        "null_profile=yes indicates an unresolved execution transition that must be fixed before enforcement."
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Group AppArmor DENIED, AUDIT, and complain-mode ALLOWED records for declaratively managed local profiles."
        )
    )
    parser.add_argument(
        "--profile",
        action="append",
        dest="profiles",
        metavar="GLOB",
        help="profile glob to include; repeatable (default: local-*)",
    )
    parser.add_argument(
        "--boot",
        default="0",
        metavar="ID",
        help="journal boot ID or offset (default: 0)",
    )
    parser.add_argument("--since", metavar="TIME", help="journalctl --since value")
    parser.add_argument("--until", metavar="TIME", help="journalctl --until value")
    parser.add_argument(
        "--input",
        metavar="PATH",
        help="read journal JSON or raw audit lines from PATH; use - for stdin",
    )
    parser.add_argument(
        "--json", action="store_true", help="emit machine-readable JSON"
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    patterns = args.profiles or ["local-*"]
    source = f"kernel journal, boot {args.boot}"
    if args.input:
        source = "standard input" if args.input == "-" else args.input

    try:
        lines: Iterable[str] = (
            input_lines(args.input) if args.input else journal_lines(args)
        )
        grouped: dict[tuple[object, ...], Finding] = {}
        counts: collections.Counter[str] = collections.Counter()
        event_profiles: set[str] = set()
        kernel_issues: list[dict[str, str]] = []
        for line in lines:
            event = parse_policy_event(line, patterns)
            if event is not None:
                add_event(grouped, event)
                counts[event.result] += 1
                event_profiles.add(event.profile)
                continue
            issue = parse_kernel_issue(line, patterns)
            if issue is not None:
                kernel_issues.append(issue)
    except (OSError, RuntimeError) as error:
        print(f"apparmor-report: {error}", file=sys.stderr)
        return 1

    findings = sorted_findings(grouped)
    profile_modes: dict[str, str] = {}
    profile_status_error: str | None = None
    service_status: dict[str, str] = {}
    service_issues: list[dict[str, str]] = []
    service_status_error: str | None = None
    if not args.input:
        if args.boot == "0":
            profile_modes, profile_status_error = current_profile_modes(patterns)
        else:
            profile_status_error = "current modes are omitted for a historical boot"
        service_status, service_issues, service_status_error = apparmor_service(args)

    report: dict[str, object] = {
        "source": source,
        "profile_patterns": patterns,
        "summary": {
            "events": counts.total(),
            "denied": counts["DENIED"],
            "audited": counts["AUDIT"],
            "allowed": counts["ALLOWED"],
            "groups": len(findings),
            "profiles": len(event_profiles),
        },
        "current_profile_modes": profile_modes,
        "profile_status_error": profile_status_error,
        "apparmor_service": service_status,
        "service_issues": service_issues,
        "service_status_error": service_status_error,
        "kernel_issues": kernel_issues,
        "findings": [finding.as_dict() for finding in findings],
    }

    if args.json:
        json.dump(report, sys.stdout, indent=2, ensure_ascii=False)
        print()
    else:
        render_text(report, findings)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

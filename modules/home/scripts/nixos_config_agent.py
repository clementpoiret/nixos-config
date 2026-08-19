#!/usr/bin/env python3
"""Human-reviewed promotion between the writable and protected NixOS config clones."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import sys
from typing import Callable, TextIO


BASE_BOOKMARK = "agent-base"
HANDOFF_BOOKMARK = "agent-handoff"
HANDOFF_REMOTE = "agent-candidate"
CONVENTIONAL_COMMIT_RE = re.compile(
    r"^[a-z][a-z0-9-]*(\([^)\r\n]+\))?!?: .+"
)


class WorkflowError(RuntimeError):
    """A safety precondition or Jujutsu operation failed."""


def _command(repo: Path | None, *arguments: str) -> list[str]:
    command = ["jj", "--no-pager", "--color=never"]
    if repo is not None:
        command.extend(("-R", str(repo)))
    command.extend(arguments)
    return command


def run_jj(
    repo: Path | None,
    *arguments: str,
    capture: bool = True,
) -> str:
    process = subprocess.run(
        _command(repo, *arguments),
        check=False,
        text=True,
        capture_output=capture,
    )
    if process.returncode != 0:
        detail = process.stderr.strip() if capture else "Jujutsu command failed"
        raise WorkflowError(detail or f"jj {' '.join(arguments)} failed")
    return process.stdout if capture else ""


def ensure_repository(path: Path, label: str) -> Path:
    resolved = path.expanduser().resolve()
    if not resolved.is_dir():
        raise WorkflowError(f"{label} repository does not exist: {resolved}")
    root = Path(run_jj(resolved, "root").strip()).resolve()
    if root != resolved:
        raise WorkflowError(f"{label} path is not a repository root: {resolved}")
    return resolved


def revision_ids(repo: Path, revset: str) -> list[str]:
    output = run_jj(
        repo,
        "log",
        "--no-graph",
        "-r",
        revset,
        "-T",
        'commit_id ++ "\\n"',
    )
    return [line for line in output.splitlines() if line]


def one_revision(repo: Path, revset: str, description: str) -> str:
    revisions = revision_ids(repo, revset)
    if len(revisions) != 1:
        raise WorkflowError(
            f"expected exactly one {description} revision, found {len(revisions)}"
        )
    return revisions[0]


def is_empty(repo: Path, revision: str = "@") -> bool:
    return len(revision_ids(repo, f"({revision}) & empty()")) == 1


def has_conflicts(repo: Path, revision: str = "@") -> bool:
    return bool(revision_ids(repo, f"({revision}) & conflicts()"))


def description(repo: Path, revision: str = "@") -> str:
    return run_jj(repo, "log", "--no-graph", "-r", revision, "-T", "description")


def protected_state(repo: Path) -> tuple[str, str]:
    current = one_revision(repo, "@", "protected working-copy")
    if not is_empty(repo):
        raise WorkflowError(
            "protected working copy must be an empty change; finish it and run `jj new` first"
        )
    if has_conflicts(repo):
        raise WorkflowError("protected working copy has conflicts")
    baseline = one_revision(repo, "parents(@)", "protected baseline parent")
    return current, baseline


def candidate_state(repo: Path, expected_baseline: str) -> tuple[str, str]:
    current = one_revision(repo, "@", "candidate working-copy")
    baseline = one_revision(repo, "parents(@)", "candidate parent")
    if baseline != expected_baseline:
        raise WorkflowError(
            "candidate parent does not match the protected baseline; reinitialize or rebase it"
        )
    if is_empty(repo):
        raise WorkflowError("candidate change is empty")
    if has_conflicts(repo):
        raise WorkflowError("candidate change has conflicts")
    change_description = description(repo).strip()
    first_line = change_description.splitlines()[0] if change_description else ""
    if not CONVENTIONAL_COMMIT_RE.fullmatch(first_line):
        raise WorkflowError(
            "candidate description must start with a Conventional Commit subject"
        )
    return current, change_description


def current_profile() -> str:
    try:
        return Path("/proc/self/attr/current").read_text(encoding="utf-8").strip()
    except OSError as error:
        raise WorkflowError(f"cannot determine the current AppArmor profile: {error}") from error


def require_unconfined(profile_reader: Callable[[], str] = current_profile) -> None:
    profile = profile_reader()
    if profile != "unconfined":
        raise WorkflowError(
            f"this command must run unconfined; current AppArmor label is {profile!r}"
        )


def configure_handoff_remote(protected: Path, candidate: Path) -> None:
    remotes: dict[str, str] = {}
    for line in run_jj(protected, "git", "remote", "list").splitlines():
        name, separator, url = line.partition(" ")
        if separator:
            remotes[name] = url.strip()
    if HANDOFF_REMOTE in remotes:
        if Path(remotes[HANDOFF_REMOTE]).expanduser().resolve() != candidate:
            run_jj(
                protected,
                "git",
                "remote",
                "set-url",
                HANDOFF_REMOTE,
                str(candidate),
            )
    else:
        run_jj(
            protected,
            "git",
            "remote",
            "add",
            HANDOFF_REMOTE,
            str(candidate),
        )


def initialize(
    protected_path: Path,
    candidate_path: Path,
    *,
    check_profile: bool = True,
) -> str:
    if check_profile:
        require_unconfined()
    protected = ensure_repository(protected_path, "protected")
    candidate = candidate_path.expanduser().resolve()
    if candidate.exists():
        raise WorkflowError(f"candidate destination already exists: {candidate}")

    _, baseline = protected_state(protected)
    run_jj(
        protected,
        "bookmark",
        "set",
        "--allow-backwards",
        "-r",
        baseline,
        BASE_BOOKMARK,
    )
    run_jj(
        None,
        "git",
        "clone",
        "--colocate",
        "--branch",
        BASE_BOOKMARK,
        str(protected),
        str(candidate),
    )

    candidate = ensure_repository(candidate, "candidate")
    if not is_empty(candidate):
        raise WorkflowError("new candidate clone did not start with an empty change")
    candidate_baseline = one_revision(candidate, "parents(@)", "candidate baseline parent")
    if candidate_baseline != baseline:
        raise WorkflowError("new candidate clone does not match the protected baseline")
    configure_handoff_remote(protected, candidate)
    return baseline


def promote(
    protected_path: Path,
    candidate_path: Path,
    *,
    confirm: Callable[[str], str] = input,
    output: TextIO = sys.stdout,
    check_profile: bool = True,
    require_tty: bool = True,
) -> str:
    if check_profile:
        require_unconfined()
    if require_tty and (not sys.stdin.isatty() or not sys.stdout.isatty()):
        raise WorkflowError("promotion requires an interactive terminal")

    protected = ensure_repository(protected_path, "protected")
    candidate = ensure_repository(candidate_path, "candidate")
    protected_current, baseline = protected_state(protected)
    candidate_current, change_description = candidate_state(candidate, baseline)

    run_jj(
        candidate,
        "bookmark",
        "set",
        "--allow-backwards",
        "-r",
        candidate_current,
        HANDOFF_BOOKMARK,
    )
    configure_handoff_remote(protected, candidate)
    run_jj(
        protected,
        "git",
        "fetch",
        "--remote",
        HANDOFF_REMOTE,
        "--branch",
        HANDOFF_BOOKMARK,
    )
    imported = one_revision(
        protected,
        f"{HANDOFF_BOOKMARK}@{HANDOFF_REMOTE}",
        "imported handoff",
    )
    if imported != candidate_current:
        raise WorkflowError("the imported handoff does not match the reviewed candidate")

    print(f"Candidate: {candidate_current}", file=output)
    print(f"Description:\n{change_description}\n", file=output)
    output.flush()
    run_jj(
        protected,
        "diff",
        "--git",
        "--from",
        baseline,
        "--to",
        imported,
        capture=False,
    )
    typed = confirm(f"Type the full candidate ID {candidate_current} to promote: ").strip()
    if typed != candidate_current:
        raise WorkflowError("confirmation did not match; protected repository was not changed")

    current_again, baseline_again = protected_state(protected)
    candidate_again, description_again = candidate_state(candidate, baseline)
    imported_again = one_revision(
        protected,
        f"{HANDOFF_BOOKMARK}@{HANDOFF_REMOTE}",
        "imported handoff",
    )
    if (
        current_again != protected_current
        or baseline_again != baseline
        or candidate_again != candidate_current
        or description_again != change_description
        or imported_again != imported
    ):
        raise WorkflowError("repository state changed during review; promotion was cancelled")

    run_jj(protected, "new", imported, "-m", "")
    try:
        candidate_after = one_revision(candidate, "@", "candidate working-copy")
        if candidate_after != candidate_current:
            raise WorkflowError(
                "protected promotion succeeded, but the candidate moved before it could be advanced"
            )
        run_jj(candidate, "new", candidate_current, "-m", "")
    except WorkflowError as error:
        raise WorkflowError(
            f"protected promotion succeeded at {imported}; candidate cleanup failed: {error}"
        ) from error
    return imported


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Manage the reviewed writable clone for the protected NixOS configuration."
    )
    parser.add_argument(
        "--protected",
        type=Path,
        default=Path.home() / "nixos-config",
        help="protected repository (default: ~/nixos-config)",
    )
    parser.add_argument(
        "--candidate",
        type=Path,
        default=Path.home() / "nixos-config-writable",
        help="agent-writable repository (default: ~/nixos-config-writable)",
    )
    parser.add_argument("action", choices=("init", "promote"))
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.action == "init":
            baseline = initialize(args.protected, args.candidate)
            print(f"Initialized {args.candidate} from protected baseline {baseline}.")
        else:
            promoted = promote(args.protected, args.candidate)
            print(f"Promoted {promoted}; both repositories now have empty working changes.")
    except WorkflowError as error:
        print(f"nixos-config-agent: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

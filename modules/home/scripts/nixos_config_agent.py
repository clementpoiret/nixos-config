#!/usr/bin/env python3
"""Human-reviewed promotion between the writable and protected NixOS config clones."""

from __future__ import annotations

import argparse
import ast
import re
import shlex
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path
from typing import TextIO

BASE_BOOKMARK = "agent-base"
HANDOFF_BOOKMARK = "agent-handoff"
HANDOFF_REMOTE = "agent-candidate"
UPSTREAM_REMOTE = "origin"
CANDIDATE_UPSTREAM_REMOTE = "github"
MAIN_BOOKMARK = "main"
CONVENTIONAL_COMMIT_RE = re.compile(r"^[a-z][a-z0-9-]*(\([^)\r\n]+\))?!?: .+")


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


def revision_ids(
    repo: Path,
    revset: str,
    *,
    ignore_working_copy: bool = False,
) -> list[str]:
    global_arguments = ["--ignore-working-copy"] if ignore_working_copy else []
    output = run_jj(
        repo,
        *global_arguments,
        "log",
        "--no-graph",
        "-r",
        revset,
        "-T",
        'commit_id ++ "\\n"',
    )
    return [line for line in output.splitlines() if line]


def one_revision(
    repo: Path,
    revset: str,
    description: str,
    *,
    ignore_working_copy: bool = False,
) -> str:
    revisions = revision_ids(
        repo,
        revset,
        ignore_working_copy=ignore_working_copy,
    )
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


def first_line(repo: Path, revision: str) -> str:
    commit_description = description(repo, revision).strip()
    return commit_description.splitlines()[0] if commit_description else ""


def display_diff(repo: Path, from_revision: str, to_revision: str) -> None:
    """Display a review diff through the user's configured Jujutsu pager."""
    diff = subprocess.run(
        _command(
            repo,
            "diff",
            "--git",
            "--from",
            from_revision,
            "--to",
            to_revision,
        ),
        check=False,
        capture_output=True,
        text=True,
    )
    if diff.returncode != 0:
        detail = diff.stderr.strip()
        raise WorkflowError(detail or "could not generate the review diff")

    pager_value = run_jj(repo, "config", "get", "ui.pager").strip()
    try:
        pager = ast.literal_eval(pager_value)
    except (SyntaxError, ValueError):
        pager = pager_value
    if isinstance(pager, str):
        pager_command = shlex.split(pager)
    elif isinstance(pager, list) and all(isinstance(item, str) for item in pager):
        pager_command = pager
    else:
        raise WorkflowError("ui.pager must be a command string or a list of strings")
    if not pager_command:
        raise WorkflowError("ui.pager is empty")

    try:
        review = subprocess.run(
            pager_command,
            check=False,
            input=diff.stdout,
            text=True,
        )
    except OSError as error:
        raise WorkflowError(
            f"could not start the configured review pager: {error}"
        ) from error
    if review.returncode != 0:
        raise WorkflowError(
            f"configured review pager exited with status {review.returncode}"
        )


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
    subject = change_description.splitlines()[0] if change_description else ""
    if not CONVENTIONAL_COMMIT_RE.fullmatch(subject):
        raise WorkflowError(
            "candidate description must start with a Conventional Commit subject"
        )
    return current, change_description


def idle_candidate_state(repo: Path, expected_baseline: str) -> str:
    current = one_revision(repo, "@", "candidate working-copy")
    baseline = one_revision(repo, "parents(@)", "candidate parent")
    if baseline != expected_baseline:
        raise WorkflowError(
            "candidate parent does not match the protected baseline; promote or rebase it first"
        )
    if not is_empty(repo):
        raise WorkflowError(
            "candidate working copy must be empty; promote the active change before pushing"
        )
    if has_conflicts(repo):
        raise WorkflowError("candidate working copy has conflicts")
    return current


def current_profile() -> str:
    try:
        return Path("/proc/self/attr/current").read_text(encoding="utf-8").strip()
    except OSError as error:
        raise WorkflowError(
            f"cannot determine the current AppArmor profile: {error}"
        ) from error


def require_unconfined(profile_reader: Callable[[], str] = current_profile) -> None:
    profile = profile_reader()
    if profile != "unconfined":
        raise WorkflowError(
            f"this command must run unconfined; current AppArmor label is {profile!r}"
        )


def remote_urls(repo: Path) -> dict[str, str]:
    remotes: dict[str, str] = {}
    for line in run_jj(repo, "git", "remote", "list").splitlines():
        name, separator, url = line.partition(" ")
        if separator:
            remotes[name] = url.strip()
    return remotes


def local_remote_path(url: str) -> Path | None:
    if url.startswith("file://"):
        return Path(url.removeprefix("file://")).expanduser().resolve()
    if "://" in url or re.match(r"^[^/]+@[^:]+:", url):
        return None
    return Path(url).expanduser().resolve()


def configure_handoff_remote(protected: Path, candidate: Path) -> None:
    remotes = remote_urls(protected)
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


def forget_handoff_tracking(protected: Path) -> None:
    run_jj(
        protected,
        "bookmark",
        "forget",
        "--include-remotes",
        f"exact:{HANDOFF_BOOKMARK}",
    )


def configure_upstream_remote(protected: Path, candidate: Path) -> str:
    protected_remotes = remote_urls(protected)
    upstream_url = protected_remotes.get(UPSTREAM_REMOTE)
    if not upstream_url:
        raise WorkflowError(
            f"protected repository has no {UPSTREAM_REMOTE!r} Git remote"
        )

    candidate_remotes = remote_urls(candidate)
    candidate_origin = candidate_remotes.get(UPSTREAM_REMOTE)
    if not candidate_origin:
        raise WorkflowError(
            f"candidate repository has no {UPSTREAM_REMOTE!r} local protected remote"
        )
    candidate_origin_path = local_remote_path(candidate_origin)
    if candidate_origin_path != protected:
        raise WorkflowError(
            "candidate origin must point to the protected repository; reinitialize it"
        )

    if CANDIDATE_UPSTREAM_REMOTE in candidate_remotes:
        if candidate_remotes[CANDIDATE_UPSTREAM_REMOTE] != upstream_url:
            run_jj(
                candidate,
                "git",
                "remote",
                "set-url",
                CANDIDATE_UPSTREAM_REMOTE,
                upstream_url,
            )
    else:
        run_jj(
            candidate,
            "git",
            "remote",
            "add",
            CANDIDATE_UPSTREAM_REMOTE,
            upstream_url,
        )
    return upstream_url


def fetch_main(repo: Path, remote: str) -> str:
    run_jj(
        repo,
        "--ignore-working-copy",
        "git",
        "fetch",
        "--remote",
        remote,
        "--branch",
        MAIN_BOOKMARK,
    )
    return one_revision(
        repo,
        f"{MAIN_BOOKMARK}@{remote}",
        f"{MAIN_BOOKMARK}@{remote}",
        ignore_working_copy=True,
    )


def bookmark_position(repo: Path, name: str) -> str | None:
    output = run_jj(
        repo,
        "--ignore-working-copy",
        "bookmark",
        "list",
        f"exact:{name}",
        "-T",
        'if(remote, "", if(conflict, "CONFLICT\\n", normal_target.commit_id() ++ "\\n"))',
    )
    positions = [line for line in output.splitlines() if line]
    if "CONFLICT" in positions or len(positions) > 1:
        raise WorkflowError(f"{name} is divergent; reconcile it before continuing")
    return positions[0] if positions else None


def restore_bookmark_position(repo: Path, name: str, position: str | None) -> None:
    if position is None:
        run_jj(
            repo,
            "--ignore-working-copy",
            "bookmark",
            "forget",
            f"exact:{name}",
        )
    else:
        run_jj(
            repo,
            "--ignore-working-copy",
            "bookmark",
            "set",
            "--allow-backwards",
            "-r",
            position,
            name,
        )


def operation_id(repo: Path) -> str:
    output = run_jj(
        repo,
        "--ignore-working-copy",
        "op",
        "log",
        "--no-graph",
        "-n",
        "1",
        "-T",
        'self.id() ++ "\\n"',
    )
    operations = [line for line in output.splitlines() if line]
    if len(operations) != 1:
        raise WorkflowError(
            f"expected exactly one current operation, found {len(operations)}"
        )
    return operations[0]


def restore_operations(checkpoints: tuple[tuple[Path, str], ...]) -> None:
    errors: list[str] = []
    for repo, checkpoint in reversed(checkpoints):
        try:
            run_jj(repo, "op", "restore", checkpoint)
        except WorkflowError as error:
            errors.append(f"{repo}: {error}")
    if errors:
        raise WorkflowError("; ".join(errors))


def is_ancestor(repo: Path, ancestor: str, descendant: str) -> bool:
    return bool(revision_ids(repo, f"({ancestor}) & ::({descendant})"))


def candidate_working_state(
    repo: Path, expected_baseline: str
) -> tuple[str, bool, str, str]:
    current = one_revision(repo, "@", "candidate working-copy")
    baseline = one_revision(repo, "parents(@)", "candidate parent")
    if baseline != expected_baseline:
        raise WorkflowError(
            "candidate parent does not match the protected baseline; reinitialize or rebase it"
        )
    if has_conflicts(repo):
        raise WorkflowError("candidate working copy has conflicts")
    return (
        current,
        is_empty(repo),
        revision_value(repo, current, "change_id"),
        description(repo, current),
    )


def synchronize_fetched_main(
    protected: Path,
    candidate: Path,
    *,
    old_main: str,
    remote_main: str,
    old_baseline: str,
    protected_current: str,
    candidate_state_before: tuple[str, bool, str, str],
) -> tuple[str, str]:
    checkpoints = (
        (protected, operation_id(protected)),
        (candidate, operation_id(candidate)),
    )
    old_baseline_change = revision_value(protected, old_baseline, "change_id")
    protected_change = revision_value(protected, protected_current, "change_id")
    candidate_current, candidate_empty, candidate_change, candidate_description = (
        candidate_state_before
    )

    try:
        # A promoted handoff is no longer needed and its remote bookmark would
        # otherwise make the protected baseline immutable during the rebase.
        forget_handoff_tracking(protected)
        run_jj(
            protected,
            "rebase",
            "--branch",
            protected_current,
            "--onto",
            remote_main,
        )
        if revision_ids(protected, f"({remote_main}..@) & conflicts()"):
            raise WorkflowError("protected rebase produced conflicts")

        new_protected_current = one_revision(
            protected, "@", "rebased protected working-copy"
        )
        if (
            revision_value(protected, new_protected_current, "change_id")
            != protected_change
        ):
            raise WorkflowError("protected working-copy change changed during rebase")
        new_baseline = one_revision(
            protected, "parents(@)", "rebased protected baseline"
        )
        if old_baseline == old_main:
            if new_baseline != remote_main:
                raise WorkflowError(
                    "protected working-copy was not rebased onto GitHub main"
                )
        elif (
            revision_value(protected, new_baseline, "change_id") != old_baseline_change
        ):
            raise WorkflowError("protected baseline change changed during rebase")

        run_jj(
            protected,
            "bookmark",
            "advance",
            f"exact:{MAIN_BOOKMARK}",
            "--to",
            remote_main,
        )
        run_jj(
            protected,
            "bookmark",
            "set",
            "--allow-backwards",
            "-r",
            new_baseline,
            BASE_BOOKMARK,
        )

        run_jj(
            candidate,
            "--ignore-working-copy",
            "git",
            "fetch",
            "--remote",
            UPSTREAM_REMOTE,
            "--branch",
            BASE_BOOKMARK,
        )
        imported_baseline = one_revision(
            candidate,
            f"{BASE_BOOKMARK}@{UPSTREAM_REMOTE}",
            f"{BASE_BOOKMARK}@{UPSTREAM_REMOTE}",
        )
        if imported_baseline != new_baseline:
            raise WorkflowError("candidate imported an unexpected protected baseline")

        run_jj(
            candidate,
            "rebase",
            "--revision",
            candidate_current,
            "--onto",
            imported_baseline,
        )
        if has_conflicts(candidate):
            raise WorkflowError("candidate rebase produced conflicts")
        new_candidate_current = one_revision(
            candidate, "@", "rebased candidate working-copy"
        )
        if (
            revision_value(candidate, new_candidate_current, "change_id")
            != candidate_change
        ):
            raise WorkflowError("candidate working-copy change changed during rebase")
        if is_empty(candidate) != candidate_empty:
            raise WorkflowError(
                "candidate working-copy emptiness changed during rebase"
            )
        if description(candidate, new_candidate_current) != candidate_description:
            raise WorkflowError("candidate description changed during rebase")
        if one_revision(candidate, "parents(@)", "candidate parent") != new_baseline:
            raise WorkflowError("candidate was not rebased onto the protected baseline")

        for bookmark in (BASE_BOOKMARK, HANDOFF_BOOKMARK):
            run_jj(
                candidate,
                "bookmark",
                "set",
                "--allow-backwards",
                "-r",
                new_baseline,
                bookmark,
            )
        return new_baseline, new_candidate_current
    except WorkflowError as error:
        try:
            restore_operations(checkpoints)
        except WorkflowError as cleanup_error:
            raise WorkflowError(
                f"{error}; synchronization rollback also failed: {cleanup_error}"
            ) from error
        raise WorkflowError(f"{error}; local state was restored") from error


def fetch_updates(
    protected_path: Path,
    candidate_path: Path,
    *,
    output: TextIO = sys.stdout,
    check_profile: bool = True,
) -> tuple[str, str]:
    if check_profile:
        require_unconfined()
    protected = ensure_repository(protected_path, "protected")
    candidate = ensure_repository(candidate_path, "candidate")
    configure_upstream_remote(protected, candidate)

    protected_current, old_baseline = protected_state(protected)
    protected_main_before = bookmark_position(protected, MAIN_BOOKMARK)
    if protected_main_before is None:
        raise WorkflowError("protected main bookmark is missing")
    candidate_state_before = candidate_working_state(candidate, old_baseline)
    candidate_main_before = bookmark_position(candidate, MAIN_BOOKMARK)
    try:
        protected_remote = fetch_main(protected, UPSTREAM_REMOTE)
        candidate_remote = fetch_main(candidate, CANDIDATE_UPSTREAM_REMOTE)
    except WorkflowError as error:
        cleanup_errors: list[str] = []
        for repo, position in (
            (protected, protected_main_before),
            (candidate, candidate_main_before),
        ):
            try:
                restore_bookmark_position(repo, MAIN_BOOKMARK, position)
            except WorkflowError as cleanup_error:
                cleanup_errors.append(str(cleanup_error))
        if cleanup_errors:
            raise WorkflowError(
                f"{error}; fetch cleanup also failed: {'; '.join(cleanup_errors)}"
            ) from error
        raise
    restore_bookmark_position(protected, MAIN_BOOKMARK, protected_main_before)
    restore_bookmark_position(candidate, MAIN_BOOKMARK, candidate_main_before)
    if protected_remote != candidate_remote:
        raise WorkflowError(
            "GitHub main changed between repository fetches; run fetch again"
        )

    print(
        f"Protected {MAIN_BOOKMARK}@{UPSTREAM_REMOTE}: {protected_remote}", file=output
    )
    print(
        f"Candidate {MAIN_BOOKMARK}@{CANDIDATE_UPSTREAM_REMOTE}: {candidate_remote}",
        file=output,
    )
    if protected_main_before == protected_remote or is_ancestor(
        protected, protected_remote, protected_main_before
    ):
        require_ancestor(
            protected,
            protected_main_before,
            old_baseline,
            "protected baseline is not a descendant of protected main",
        )
        print(f"Protected {MAIN_BOOKMARK}: {protected_main_before}", file=output)
        print(
            "Fetched GitHub metadata; protected main already contains GitHub main.",
            file=output,
        )
        return protected_remote, candidate_remote
    if not is_ancestor(protected, protected_main_before, protected_remote):
        raise WorkflowError(
            "protected main has diverged from GitHub main; local state was not moved"
        )
    require_ancestor(
        protected,
        protected_main_before,
        old_baseline,
        "protected baseline is not a descendant of protected main",
    )

    new_baseline, new_candidate = synchronize_fetched_main(
        protected,
        candidate,
        old_main=protected_main_before,
        remote_main=protected_remote,
        old_baseline=old_baseline,
        protected_current=protected_current,
        candidate_state_before=candidate_state_before,
    )
    print(f"Protected {MAIN_BOOKMARK}: {protected_remote}", file=output)
    print(f"Protected baseline: {old_baseline} -> {new_baseline}", file=output)
    print(
        f"Candidate working-copy: {candidate_state_before[0]} -> {new_candidate}",
        file=output,
    )
    print("GitHub main advanced and local work was rebased.", file=output)
    return protected_remote, candidate_remote


def revision_value(repo: Path, revision: str, template: str) -> str:
    return run_jj(
        repo,
        "log",
        "--no-graph",
        "-r",
        revision,
        "-T",
        template,
    ).strip()


def commit_fingerprint(repo: Path, revision: str) -> tuple[str, str]:
    return (
        revision_value(repo, revision, "change_id"),
        description(repo, revision),
    )


def revisions_are_logically_equivalent(repo: Path, first: str, second: str) -> bool:
    if commit_fingerprint(repo, first) != commit_fingerprint(repo, second):
        return False
    first_parents = sorted(
        revision_value(repo, parent, "change_id")
        for parent in revision_ids(repo, f"parents({first})")
    )
    second_parents = sorted(
        revision_value(repo, parent, "change_id")
        for parent in revision_ids(repo, f"parents({second})")
    )
    if first_parents != second_parents:
        return False
    return not run_jj(
        repo,
        "diff",
        "--summary",
        "--from",
        first,
        "--to",
        second,
    ).strip()


def require_ancestor(repo: Path, ancestor: str, descendant: str, detail: str) -> None:
    if not revision_ids(repo, f"({ancestor}) & ::({descendant})"):
        raise WorkflowError(detail)


def validate_publish_range(repo: Path, remote_main: str, target: str) -> list[str]:
    revisions = revision_ids(repo, f"{remote_main}..{target}")
    if not revisions:
        raise WorkflowError("there are no unpublished revisions to push")
    if revision_ids(repo, f"({remote_main}..{target}) & conflicts()"):
        raise WorkflowError("unpublished revisions contain conflicts")
    for revision in revisions:
        subject = first_line(repo, revision)
        if not CONVENTIONAL_COMMIT_RE.fullmatch(subject):
            raise WorkflowError(
                f"unpublished revision {revision} does not have a Conventional Commit subject"
            )
    return revisions


def synchronize_candidate(
    candidate: Path,
    *,
    expected_old_baseline: str,
    target: str,
    remote: str,
    branch: str,
) -> None:
    candidate_current = idle_candidate_state(candidate, expected_old_baseline)
    candidate_change = revision_value(candidate, candidate_current, "change_id")
    run_jj(
        candidate,
        "--ignore-working-copy",
        "git",
        "fetch",
        "--remote",
        remote,
        "--branch",
        branch,
    )
    imported = one_revision(
        candidate,
        f"{branch}@{remote}",
        f"{branch}@{remote}",
    )
    if imported != target:
        raise WorkflowError(
            f"candidate fetched {branch}@{remote} at an unexpected revision"
        )

    current_after_fetch = one_revision(candidate, "@", "candidate working-copy")
    if revision_value(candidate, current_after_fetch, "change_id") != candidate_change:
        raise WorkflowError("candidate working-copy changed while synchronizing")
    if not is_empty(candidate) or has_conflicts(candidate):
        raise WorkflowError("candidate working-copy changed while synchronizing")
    parent_after_fetch = one_revision(candidate, "parents(@)", "candidate parent")
    expected_parent = parent_after_fetch in (expected_old_baseline, target)
    if not expected_parent and revisions_are_logically_equivalent(
        candidate, parent_after_fetch, target
    ):
        expected_parent = True
    if not expected_parent:
        raise WorkflowError("candidate parent changed while synchronizing")
    if parent_after_fetch != target:
        run_jj(candidate, "rebase", "-r", "@", "-d", target)

    for bookmark in (BASE_BOOKMARK, HANDOFF_BOOKMARK):
        run_jj(
            candidate,
            "bookmark",
            "set",
            "--allow-backwards",
            "-r",
            target,
            bookmark,
        )
    idle_candidate_state(candidate, target)


def restore_after_cancelled_push(
    protected: Path,
    candidate: Path,
    *,
    original_main: str,
    old_baseline: str,
    signed_target: str,
) -> None:
    errors: list[str] = []
    try:
        run_jj(
            protected,
            "bookmark",
            "set",
            "--allow-backwards",
            "-r",
            original_main,
            MAIN_BOOKMARK,
        )
        run_jj(
            protected,
            "bookmark",
            "set",
            "--allow-backwards",
            "-r",
            signed_target,
            BASE_BOOKMARK,
        )
    except WorkflowError as error:
        errors.append(f"could not restore protected bookmarks: {error}")
    try:
        synchronize_candidate(
            candidate,
            expected_old_baseline=old_baseline,
            target=signed_target,
            remote=UPSTREAM_REMOTE,
            branch=BASE_BOOKMARK,
        )
    except WorkflowError as error:
        errors.append(f"could not realign the candidate: {error}")
    if errors:
        raise WorkflowError("; ".join(errors))


def push(
    protected_path: Path,
    candidate_path: Path,
    *,
    confirm: Callable[[str], str] = input,
    output: TextIO = sys.stdout,
    review_diff: Callable[[Path, str, str], None] = display_diff,
    check_profile: bool = True,
    require_tty: bool = True,
) -> str:
    if check_profile:
        require_unconfined()
    if require_tty and (not sys.stdin.isatty() or not sys.stdout.isatty()):
        raise WorkflowError("push requires an interactive terminal")

    protected = ensure_repository(protected_path, "protected")
    candidate = ensure_repository(candidate_path, "candidate")
    remote_main, candidate_remote_main = fetch_updates(
        protected,
        candidate,
        output=output,
        check_profile=False,
    )
    _, baseline = protected_state(protected)
    candidate_current = idle_candidate_state(candidate, baseline)
    if candidate_remote_main != remote_main:
        raise WorkflowError(
            "candidate GitHub metadata does not match the protected clone"
        )

    local_main = one_revision(protected, MAIN_BOOKMARK, "protected main")
    require_ancestor(
        protected,
        remote_main,
        local_main,
        "protected main has diverged from GitHub main; reconcile it before pushing",
    )
    require_ancestor(
        protected,
        local_main,
        baseline,
        "protected baseline is not a descendant of protected main",
    )
    validate_publish_range(protected, remote_main, baseline)

    baseline_fingerprint = commit_fingerprint(protected, baseline)
    unsigned = revision_ids(
        protected,
        f"({remote_main}..{baseline}) ~ signed()",
    )
    if unsigned:
        # The handoff is no longer needed after promotion, and its remote bookmark
        # would otherwise make the unpublished target immutable.
        forget_handoff_tracking(protected)
        run_jj(
            protected,
            "sign",
            "-r",
            f"({remote_main}..{baseline}) ~ signed()",
        )

    signed_current, signed_target = protected_state(protected)
    tree_difference = run_jj(
        protected,
        "diff",
        "--summary",
        "--from",
        baseline,
        "--to",
        signed_target,
    ).strip()
    if (
        commit_fingerprint(protected, signed_target) != baseline_fingerprint
        or tree_difference
    ):
        raise WorkflowError("signing unexpectedly changed the target revision contents")
    original_main = one_revision(protected, MAIN_BOOKMARK, "signed protected main")
    validate_publish_range(protected, remote_main, signed_target)
    if revision_ids(protected, f"({remote_main}..{signed_target}) ~ signed()"):
        raise WorkflowError("one or more unpublished revisions could not be signed")

    published = False
    try:
        changes = run_jj(
            protected,
            "log",
            "--no-graph",
            "-r",
            f"{remote_main}..{signed_target}",
            "-T",
            '"  " ++ commit_id ++ "  " ++ description.first_line() ++ "\\n"',
        )
        print("Signed revisions to publish:", file=output)
        print(changes.rstrip(), file=output)
        print(
            f"Cumulative diff: {remote_main}..{signed_target}",
            file=output,
        )
        output.flush()
        review_diff(protected, remote_main, signed_target)

        run_jj(
            protected,
            "bookmark",
            "set",
            "--allow-backwards",
            "-r",
            signed_target,
            MAIN_BOOKMARK,
        )
        run_jj(
            protected,
            "git",
            "push",
            "--dry-run",
            "--remote",
            UPSTREAM_REMOTE,
            "--bookmark",
            f"exact:{MAIN_BOOKMARK}",
            capture=False,
        )
        typed = confirm(
            f"Type the full signed target ID {signed_target} to push to GitHub: "
        ).strip()
        if typed != signed_target:
            raise WorkflowError("confirmation did not match; GitHub was not changed")

        current_again, target_again = protected_state(protected)
        if current_again != signed_current or target_again != signed_target:
            raise WorkflowError("protected repository changed during review")
        if one_revision(protected, MAIN_BOOKMARK, "protected main") != signed_target:
            raise WorkflowError("protected main changed during review")
        if (
            one_revision(
                protected,
                f"{MAIN_BOOKMARK}@{UPSTREAM_REMOTE}",
                "GitHub main",
            )
            != remote_main
        ):
            raise WorkflowError("GitHub metadata changed during review; run push again")
        if one_revision(candidate, "@", "candidate working-copy") != candidate_current:
            raise WorkflowError("candidate working-copy changed during review")
        idle_candidate_state(candidate, baseline)

        run_jj(
            protected,
            "git",
            "push",
            "--remote",
            UPSTREAM_REMOTE,
            "--bookmark",
            f"exact:{MAIN_BOOKMARK}",
            capture=False,
        )
        published = True

        if one_revision(protected, MAIN_BOOKMARK, "protected main") != signed_target:
            raise WorkflowError("protected main does not match the published target")
        if (
            one_revision(
                protected,
                f"{MAIN_BOOKMARK}@{UPSTREAM_REMOTE}",
                "published GitHub main",
            )
            != signed_target
        ):
            raise WorkflowError("GitHub main does not match the published target")
        _, final_baseline = protected_state(protected)
        if final_baseline != signed_target:
            raise WorkflowError(
                "protected working-copy is not based on the published target"
            )

        run_jj(
            protected,
            "bookmark",
            "set",
            "--allow-backwards",
            "-r",
            signed_target,
            BASE_BOOKMARK,
        )
        synchronize_candidate(
            candidate,
            expected_old_baseline=baseline,
            target=signed_target,
            remote=CANDIDATE_UPSTREAM_REMOTE,
            branch=MAIN_BOOKMARK,
        )
        return signed_target
    except WorkflowError as error:
        if published:
            raise WorkflowError(
                f"GitHub push succeeded at {signed_target}, but local synchronization failed: {error}"
            ) from error
        try:
            restore_after_cancelled_push(
                protected,
                candidate,
                original_main=original_main,
                old_baseline=baseline,
                signed_target=signed_target,
            )
        except WorkflowError as cleanup_error:
            raise WorkflowError(
                f"{error}; cancellation cleanup also failed: {cleanup_error}"
            ) from error
        raise


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
    candidate_baseline = one_revision(
        candidate, "parents(@)", "candidate baseline parent"
    )
    if candidate_baseline != baseline:
        raise WorkflowError("new candidate clone does not match the protected baseline")
    configure_handoff_remote(protected, candidate)
    configure_upstream_remote(protected, candidate)
    return baseline


def promote(
    protected_path: Path,
    candidate_path: Path,
    *,
    confirm: Callable[[str], str] = input,
    output: TextIO = sys.stdout,
    review_diff: Callable[[Path, str, str], None] = display_diff,
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
        raise WorkflowError(
            "the imported handoff does not match the reviewed candidate"
        )

    print(f"Candidate: {candidate_current}", file=output)
    print(f"Description:\n{change_description}\n", file=output)
    output.flush()
    review_diff(protected, baseline, imported)
    typed = confirm(
        f"Type the full candidate ID {candidate_current} to promote: "
    ).strip()
    if typed != candidate_current:
        raise WorkflowError(
            "confirmation did not match; protected repository was not changed"
        )

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
        raise WorkflowError(
            "repository state changed during review; promotion was cancelled"
        )

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
    parser.add_argument("action", choices=("init", "promote", "fetch", "push"))
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.action == "init":
            baseline = initialize(args.protected, args.candidate)
            print(f"Initialized {args.candidate} from protected baseline {baseline}.")
        elif args.action == "promote":
            promoted = promote(args.protected, args.candidate)
            print(
                f"Promoted {promoted}; both repositories now have empty working changes."
            )
        elif args.action == "fetch":
            fetch_updates(args.protected, args.candidate)
        else:
            published = push(args.protected, args.candidate)
            print(
                f"Pushed {published}; protected and candidate clones are synchronized."
            )
    except WorkflowError as error:
        print(f"nixos-config-agent: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

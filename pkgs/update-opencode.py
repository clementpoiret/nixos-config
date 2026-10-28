#!/usr/bin/env python3
"""Advance OpenCode's verified source pin only for a newer stable release."""

import json
from pathlib import Path
import re
import subprocess


BOOTSTRAP_REVISION = "6abf95b947cf6f452a3901ac8cbfe6efa670c7ca"
BOOTSTRAP_VERSION = (2, 2, 0)
INPUT_PATTERN = re.compile(r'^      url = "github:anomalyco/opencode/([^"\n]+)";$', re.MULTILINE)


def release_version(tag):
    if not isinstance(tag, str) or not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag):
        return None
    return tuple(map(int, tag[1:].split(".")))


def update_release(flake, releases):
    content = flake.read_text()
    matches = list(INPUT_PATTERN.finditer(content))
    if len(matches) != 1:
        raise ValueError("Expected exactly one pinned OpenCode input")
    match = matches[0]
    current = match.group(1)
    current_version = BOOTSTRAP_VERSION if current == BOOTSTRAP_REVISION else release_version(current)
    if current_version is None:
        raise ValueError(f"Unknown OpenCode pin: {current}")

    candidates = []
    for release in releases:
        version = release_version(release["tag_name"])
        if release["draft"] is False and release["prerelease"] is False and version is not None:
            candidates.append((version, release["tag_name"]))
    if not candidates:
        raise ValueError("No stable OpenCode releases found")
    version, tag = max(candidates)
    if version <= current_version:
        print(f"opencode: keeping {current}; no newer stable release")
        return

    flake.write_text(content[:match.start(1)] + tag + content[match.end(1):])
    print(f"opencode: {current} -> {tag}")


def fetch_releases():
    output = subprocess.check_output([
        "gh", "api", "--paginate",
        "--header", "X-GitHub-Api-Version: 2022-11-28",
        "repos/anomalyco/opencode/releases?per_page=100",
        "--jq", ".[] | {tag_name, draft, prerelease} | @json",
    ], text=True)
    return [json.loads(line) for line in output.splitlines()]


if __name__ == "__main__":
    update_release(Path(__file__).resolve().parent.parent / "flake.nix", fetch_releases())

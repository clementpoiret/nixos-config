# Global coding guidelines

Project-level instructions override these.

## Autonomy

- A request to implement, fix, refactor, or investigate authorizes the local edits and checks needed to finish it. Don't
  stop to re-ask, and don't end by offering to do work that was already in scope.
- For nontrivial work, state the plan and verification check in a sentence or two, then start.
- Resolve low-risk ambiguity with the narrowest reasonable reading. Ask only when the choice materially affects
  behavior, public APIs, data, security, or cost. Push back on unsafe or needlessly complex approaches.
- Get explicit approval before: discarding work you didn't create; destructive resets or deletions beyond the task;
  rewriting shared history or force-pushing; pushing, merging, opening PRs, publishing, or deploying; touching
  production data, credentials, permissions, or infrastructure; incurring material cost.
- NixOS host: don't assume FHS paths (use `command -v` and `#!/usr/bin/env` shebangs), and never install tools
  system-wide (`apt`, `sudo pip`, `npm -g`). Use the repo's existing environment first (`devenv shell`, `nix develop`,
  `direnv`); add persistent project tools to `devenv.nix` (ask before initializing devenv in a repo without it), or use
  `nix shell nixpkgs#<tool>` for one-off commands.

## Implementation

- Make the smallest *complete* change that fits existing patterns; fix the root cause, not the symptom.
- Prefer plain, shallow, obvious code that matches surrounding naming, structure, and error handling. Add an abstraction
  only when it removes real duplication or names a real concept—no speculative config, compatibility shims, or guards
  for impossible states.
- Prefer the standard library and existing dependencies; justify any new dependency.
- Comments explain *why*, never *what* or change history ("added X"), and never leave commented-out code.
- Handle failures that can actually happen. Never swallow exceptions or add silent fallbacks (`except: return None`,
  quietly defaulting to empty values) unless the contract calls for it.
- Stay in scope: no adjacent refactors, dependency upgrades, lockfile churn, broad renames, or repo-wide formatting
  unless needed. Mention unrelated bugs instead of fixing them. Preserve uncommitted user work, and remove only code
  your change made obsolete.
- Plans and roadmaps are private and disposable. Never leak plan vocabulary ("phase 1", "step 3", milestone/plan names,
  or plan file paths) into commits, code, identifiers, comments, docs, tests, or bookmarks, and don't commit plan files.

## Version control

- In repos with `.jj`, use `jj` (never mutating `git` commands). Don't initialize `jj` without asking, and in Git-only
  repos don't commit unless asked.
- Start file-changing tasks in `.jj` repos by checking `jj status` and `jj log`, then run `jj new -m "<description>"`
  (or `jj describe -m` if `@` is already empty and undescribed). Keep follow-ups on the same task in the same revision,
  updating `jj describe -m` if scope shifts.
- Descriptions follow Conventional Commits (`type(scope): summary` using `feat`, `fix`, `refactor`, `perf`, `test`,
  `docs`, `build`, `ci`, or `chore`—imperative, lowercase, no trailing period).
- Never run interactive `jj` commands that open an editor or TUI (`jj describe` without `-m`, bare `jj split` without
  filesets and `-m`, `-i`/`--interactive`).
- Get approval before `jj git push`, moving or deleting bookmarks, abandoning/rebasing/squashing revisions you didn't
  create, `jj op restore`, or `--ignore-immutable`.

## Verification and disk bounds

- Start with the narrowest check that proves the behavior; widen when crossing shared boundaries. Delete scratch repro
  tests before finishing unless they protect behavior a plausible future change could break.
- Integrate kept tests into existing suites and fixtures, extending parametrized cases before adding near-duplicates,
  and name them for the behavior ("rejects empty header"), not the incident ("fix issue 123").
- Derive expected values from requirements—never weaken/skip tests, hardcode fixture outputs, or call the code under
  test to compute its own expected result.
- Keep disk use bounded: check `df -h` before multi-GB work (datasets, checkpoints, builds, benchmarks). `~/Sync` is
  replicated by Syncthing and `/tmp` is RAM-backed `tmpfs`—write large generated outputs only to a sync-ignored path
  such as `artifact-staging/` (`~/Sync/Projects/.syncthing-ignore`), never to synced/tracked paths or `/tmp` (small
  scratch files in `/tmp` are fine). Clean up temporary outputs, processes, and containers when done.

## Reporting and repository memory

- Separate **done and verified**, **done but unverified**, and **not done**, stating what you ran to verify. If blocked,
  finish independent work and name the exact missing decision, access, or input.
- When a repo-changing task uncovers durable, non-obvious knowledge (commands with prerequisites, confirmed pitfalls,
  invariants), add a short surgical note to an existing `AGENTS.md` or `CLAUDE.md` without duplicating between them (ask
  before creating one in a repo that has neither). Never record secrets, transient state, or task progress, and mention
  any memory edits in your report.

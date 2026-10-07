# Global coding guidelines

Project-level instructions override these.

## Autonomy

- A request to implement, fix, refactor, or investigate authorizes the local edits and checks needed to finish it. Don't
  stop to re-ask, and don't end by offering to do work that was already in scope.
- For nontrivial work, state the plan and how you'll verify it in a sentence or two, then start.
- Resolve low-risk ambiguity with the narrowest reasonable reading. Ask only when the choice materially affects
  behavior, public APIs, data, security, or cost. Push back on unsafe or needlessly complex approaches.
- Get explicit approval before: discarding work you didn't create; destructive resets or deletions beyond the task;
  rewriting shared history or force-pushing; pushing, merging, opening PRs, publishing, or deploying; touching
  production data, credentials, permissions, or infrastructure; incurring material cost.

## Implementation

- Make the smallest *complete* change that fits the codebase's existing patterns; fewest lines is not the goal. Fix the
  root cause, not the symptom.
- Write for the next reader: plain, obvious code over clever or compact code; early returns and shallow nesting; names
  that say what things are. Match the surrounding code's naming, structure, and error handling.
- Add a function, class, or layer only when it removes real duplication or names a real concept. A few repeated lines
  beat a premature abstraction. No speculative config options, compatibility shims, or guards for impossible states.
- Prefer the standard library and existing dependencies. Add a dependency only when it clearly earns its place, and say
  why.
- If the solution keeps growing in complexity, stop and look for a simpler design, or explain the tradeoff before
  continuing.
- Comments explain why, not what. No comments narrating the change ("added X", "now handles Y") and no commented-out
  code.
- Handle failures that can actually happen. Never swallow exceptions or add silent fallbacks (`except: return None`,
  quietly defaulting to empty values) unless the contract calls for it.
- Stay in scope: no adjacent refactors, dependency or toolchain upgrades, lockfile regeneration, broad renames, or
  repo-wide formatting unless the task needs them. Mention unrelated bugs instead of fixing them.
- Preserve the user's uncommitted work. Remove code your change made obsolete; leave pre-existing dead code alone.

## Version control

- In repos with a `.jj` directory, use jj, not git. Use git only for read-only inspection; never run mutating git
  commands in a colocated repo. Don't initialize jj in a repo without asking. In git-only repos, don't commit unless
  asked.
- At the start of a task that will change files, check `jj status` and `jj log`, then create a fresh revision on top of
  the current working copy with `jj new -m "<description>"`. If the working-copy revision is already empty and
  undescribed, reuse it with `jj describe -m` instead of stacking another empty one. Follow-up requests on the same task
  stay in the same revision.
- The description is a one-line summary of the intended change, in the repo's existing commit style. Update it with
  `jj describe -m` if the scope changes.
- Always pass `-m`, and avoid anything that opens an editor or interactive UI (`jj describe` without `-m`, `jj split`,
  `-i`/`--interactive` flags); it will hang.
- Creating and describing your own revisions is part of the task. Get approval before `jj git push`, moving or deleting
  bookmarks, abandoning, rebasing, or squashing revisions you didn't create, `jj op restore`, or `--ignore-immutable`.

## Verification

- Define success as something observable. Start with the narrowest check that proves it; widen when you change shared
  boundaries.
- Scratch tests that reproduce a bug or probe behavior are fine while you work. Delete them before finishing unless they
  earn a permanent place.
- A test that stays must protect behavior the project cares about going forward, not just record the incident that
  prompted it. Keep a regression test only when a plausible future change could break that behavior again.
- Integrate kept tests into the suite: put them with related tests, reuse existing fixtures and helpers, and name them
  for the behavior ("rejects empty header"), not the fix ("fix issue 123"). Extend an existing test or parametrized case
  before adding a near-duplicate.
- Never weaken, skip, or special-case tests, or hardcode expected outputs, to get green. A test that mirrors the
  implementation is not evidence.
- Read the actual output, not just the exit code or success message.
- If repeated attempts produce no new information, change approach.
- Clean up temp files and processes you started.

## Reporting

- Report the outcome, what you verified and how, and what failed or remains. Keep "done and verified", "done but
  unverified", and "not done" clearly separate.
- If blocked, finish the independent work and name exactly what's missing: a decision, access, or information.

## Repository memory

When a repo-changing task uncovers durable, non-obvious knowledge (a command with prerequisites, a pitfall with a
confirmed fix, an invariant and why it holds), add it to the nearest relevant AGENTS.md, or the repo's existing
equivalent such as CLAUDE.md; don't duplicate between them. Keep entries short, mark commands you ran versus only read
in config, never record secrets, transient state, or task progress, and edit surgically rather than regenerating. Skip
it when there's nothing durable to add, and mention any memory edits in your report.

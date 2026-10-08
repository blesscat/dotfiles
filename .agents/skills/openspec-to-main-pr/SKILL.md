---
name: openspec-to-main-pr
description: Complete an explicitly requested OpenSpec-to-PR workflow, from an agreed plan through implementation, dual review, spec sync, archive, and a PR ready for review on main.
---

# OpenSpec to Main PR

Finish the authorized delivery workflow in this order:
`$openspec-propose` → `$openspec-apply-review` → `$openspec-sync-specs` →
`$openspec-archive-change` → commit, push, and PR ready for review on `main`.
Never merge, push directly to main, or resolve PR reviews as part of this skill.

## Scope and continuation

Use the requirements and decisions already established in conversation. Do not
restart exploration when they are sufficient. If the user is still brainstorming,
stay in exploration until the intended outcome is clear.

The explicit end-to-end request authorizes continuation between these phases.
A planning skill's standalone handoff ends that phase, not the overall task.
Within this orchestration, carry the user's existing authorization into the next
phase without requesting a new message. This does not bypass CLI blocked states,
validation, filesystem permissions, or a newly required product decision.

Fix recoverable in-scope implementation and verification failures, then continue.
Pause only when progress requires missing authority, an external prerequisite,
an unresolved material requirement, or the review gate reaches its limit.
User follow-ups steer the task unless they cancel or replace it.

## Initial worktree isolation

Before writes, inspect `pwd`, `git status --short --branch --untracked-files=all`, and
`git worktree list --porcelain`. Record pre-existing changes separately from
changes created by this run.

Check for unmerged paths with `git diff --name-only --diff-filter=U` and for
in-progress Git operations using `git rev-parse --git-path <marker>` to resolve
`MERGE_HEAD`, `rebase-merge`, `rebase-apply`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`,
and `sequencer`. An unmerged path or any of these operation markers prevents
checkout reuse, including when only lockfiles are affected. Preserve the
original conflict and operation state and use the focused worktree procedure
below instead.

For this isolation decision only, disregard untracked (`??`) entries under the
checkout-root `.orca/` directory and pre-existing non-conflicted files whose
basenames end in `lock.yaml` at any directory depth, whether untracked,
modified, staged, added, deleted, or renamed. This includes
`pnpm-lock.yaml`, `.pnpm-lock.yaml`, and `apps/web/pnpm-lock.yaml`. Preserve
these pre-existing changes without staging or publishing them unless the task
explicitly includes them; do not change Git ignore rules for this exception.
All other untracked entries and tracked, staged, deleted, or conflicted changes
remain pre-existing file changes.

This classification does not make ignored lockfile contents trusted dependency
inputs. Before dependency setup, project checks, or hooks that execute installed
tools, establish that their installation used trusted dependency manifests and
lockfiles from the intended HEAD, plus dependency changes explicitly included
in this task. Never install from excluded pre-existing lockfile changes or run
tools whose installation used those changes; a frozen install does not provide
this provenance.

If existing tooling provenance cannot be established, prepare a disposable,
credential-free verification copy with trusted HEAD dependency inputs and only
attributable task changes. Exclude unrelated lockfile changes from that copy, run the
required checks there, and keep edits and PR commits on the selected branch.
Preserve the original lockfiles without restoring or swapping their contents.
If publishing hooks would execute unverified tooling in the original checkout,
disable those hooks per Git command only after the required checks pass in the
trusted copy; do not change shared Git config or bypass required verification.
If trusted verification cannot be established, report the blocker before running
dependency setup, checks, or those hooks.

Reuse the current checkout directly when it has no pre-existing file changes
after this classification, no unmerged paths or in-progress Git operations,
and its current branch is not `main`. This includes
existing linked worktrees at other paths and branches created for earlier tasks.
Do not create a new branch or worktree because of its path, name, ownership,
or starting HEAD and base. Record existing branch commits, upstream, and any
PR so the publishable scope can be checked. Only a checkout on `main`, a
detached HEAD, or one carrying meaningful pre-existing file changes, unmerged
paths, or in-progress Git operations needs a
new focused non-main branch and worktree under the target repository's
`<project-root>/.worktree/<name>`
(singular). Resolve the owning repository root before creating a worktree;
when already inside a linked worktree, use Git's worktree list and common
directory to identify its owner instead of nesting another .worktree beneath
the linked worktree. A built-in worktree used for a new checkout is acceptable
only when it satisfies this location.

Before creating the nested worktree, run `git check-ignore -v --no-index
<worktree-path>` from the owning checkout. If it is not ignored, append only
`/.worktree/` to the repository-local exclude file resolved by
`git rev-parse --git-path info/exclude` from that checkout, preserving existing
content. Recheck that the exclusion is effective before creating the worktree;
if it cannot be established, report the blocker without nesting it. This local
Git metadata change leaves the original checkout's tracked files untouched.

Gate this ignore setup on actually creating the focused worktree; when an
existing checkout is reused, this run creates no nested worktree and skips it
entirely. If the versioned root .gitignore lacks `.worktree/`, add that rule in
the focused checkout and include it in the feature commit. Keep the local
exclude while the owning checkout lacks the versioned rule, including when
delivery pauses before merge. Verify its status has no new untracked
`.worktree/` entry. Keep all other ignore policy unchanged.

At initial entry, reuse the current checkout when the reuse conditions above
hold; otherwise create the focused worktree from the intended HEAD.
Preserve original uncommitted work without stashing, resetting, or committing
it. If task inputs exist only in the original dirty checkout, inspect them
read-only and establish how to carry the authorized work forward; never
silently omit it. Pause if ownership cannot be separated safely.

After implementation starts, this run's uncommitted changes are expected.
Do not create another worktree merely because those changes exist. When resuming,
reuse the established branch and worktree after checking identity and scope.

## OpenSpec phases

Require the openspec CLI and the four named phase skills above, including
subagent support for the dual-review gate. Resolve skills from the active
installation. Do not substitute self-review or a single reviewer.

Keep the selected change and planning root stable. For a named store, discover
its id with `openspec store list --json` and retain `--store <id>` on applicable
commands. Use CLI-returned schema, artifact paths, and context instead of assuming
repository-local paths.

1. **Proposal:** Inspect existing changes and reuse a matching change rather than
   duplicating it. Apply project context and schema rules through the proposal
   skill. Verify all prerequisites for apply are satisfied.
2. **Apply and review:** Use `$openspec-apply-review`. Require completed tasks,
   relevant verification, and a passing pair of independent read-only reviewers.
   Preserve its exactly-two-reviewers and maximum-five-rounds contract.
3. **Sync:** Invoke `$openspec-sync-specs` explicitly. Preserve requirements and
   scenarios outside the selected delta. Require successful
   `openspec validate --specs` with the selected-root flags. A confirmed absence
   of delta specs is a successful no-op.
4. **Archive:** Invoke `$openspec-archive-change` only after sync succeeds.
   Verify every delta is reflected in main specs and take the already-synced
   archive path. If differences remain, return to the separate sync phase.
   Do not replace that phase with inline archive sync. Preserve .openspec.yaml,
   verify the dated archive exists and the active change is gone, and do not
   overwrite an existing archive.

Let phase skills own their detailed command and artifact procedures. Reuse
unchanged context and validation evidence; refresh it when state or inputs change.

## Publish

Verify the current checkout and selected non-main branch remain in use. Inspect
the complete publishable diff, including untracked files, synchronized specs,
and any pre-existing commits on the branch. This run's unstaged changes are
eligible for staging; unrelated changes remain excluded. If pre-existing
commits or a PR on the branch would publish unrelated work, pause for a scope
decision before publishing.

Resolve origin and verify that main exists. Use an available authenticated Git
and GitHub publishing path. A connector alternative must preserve the intended
branch ancestry and complete change, including deletions and binary assets;
do not rebuild only text patches on a different base. Stop if the available
capability cannot publish an equivalent result.

- Apply root and relevant nested .gitignore rules to every candidate path.
  Never force-add ignored paths or bypass ignore rules through a connector.
  Ignored archives remain local; publishing them requires a separate explicit
  decision to change ignore policy.
- Stage only attributable, non-ignored task changes. If unrelated lockfiles
  are already staged, commit only the explicit task paths (for example,
  `git commit --only -- <task-paths>`) to preserve their index state while
  excluding them from the commit. Inspect the publishable staged diff and
  `git diff --cached --check -- <task-paths>`. Make one or more cohesive commits.
- Complete required repository checks. Rerun affected checks when subsequent
  edits invalidate earlier results; otherwise reuse the recorded results.
- Push the feature branch with tracking. Create a PR ready for review against
  `main`, describing the final behavior, OpenSpec change, review outcome,
  verification, and material residual risk.
- Verify the pushed head, PR URL, source branch, base, and confirm the PR is not
  a draft. If a matching PR already exists on a resumed run, update it instead
  of duplicating it.

## Completion

Report the change, sync/archive status and location, local-only ignored artifacts,
both reviewer verdicts and rounds used, validation results, branch, commit, and PR
URL. All publishable work from this task must be committed and pushed.
If blocked, identify the last completed phase and the concrete prerequisite to
resume; do not report a partial run as complete.

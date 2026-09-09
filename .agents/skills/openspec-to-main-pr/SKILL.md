---
name: openspec-to-main-pr
description: Complete an explicitly requested OpenSpec-to-PR workflow, from an agreed plan through implementation, dual review, spec sync, archive, and a draft PR to main.
---

# OpenSpec to Main PR

Finish the authorized delivery workflow in this order:
`$openspec-propose` → `$openspec-apply-review` → `$openspec-sync-specs` →
`$openspec-archive-change` → commit, push, and draft PR to `main`.
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

Before writes, inspect `pwd`, `git status --short --branch`, and
`git worktree list --porcelain`. Record pre-existing changes separately from
changes created by this run.

Use a focused non-main branch under the target repository's
`<project-root>/.worktree/<name>` (singular). Resolve the owning repository root
before creating a worktree; when already inside a linked worktree, use Git's
worktree list and common directory to identify its owner instead of nesting
another .worktree beneath the linked worktree. A built-in worktree is acceptable
only when it satisfies this location.

Verify that the target project's ignore rules cover `.worktree/` with
`git check-ignore -v --no-index <worktree-path>`. If needed, add only the root
`.worktree/` ignore rule in the focused checkout and include that deliberate
change in the feature commit. Do not edit the original checkout to bootstrap it.
Keep all other ignore policy unchanged.

At initial entry, reuse a clean focused worktree at that location or create one
from the intended HEAD. Preserve original uncommitted work without stashing,
resetting, or committing it. If task inputs exist only in the original dirty
checkout, inspect them read-only and establish how to carry the authorized work
forward; never silently omit it. Pause if ownership cannot be separated safely.

After implementation starts, this run's uncommitted changes are expected.
Do not create another worktree merely because those changes exist. When resuming,
reuse the established branch and worktree after checking ownership and scope.

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

Verify the current worktree and feature branch still match this run. Inspect the
complete publishable diff, including untracked files, synchronized specs, and
any intended commits already on the branch. This run's unstaged changes are
eligible for staging; unrelated changes remain excluded.

Resolve origin and verify that main exists. Use an available authenticated Git
and GitHub publishing path. A connector alternative must preserve the intended
branch ancestry and complete change, including deletions and binary assets;
do not rebuild only text patches on a different base. Stop if the available
capability cannot publish an equivalent result.

- Apply root and relevant nested .gitignore rules to every candidate path.
  Never force-add ignored paths or bypass ignore rules through a connector.
  Ignored archives remain local; publishing them requires a separate explicit
  decision to change ignore policy.
- Stage only attributable, non-ignored task changes. Inspect the staged diff
  and `git diff --cached --check`. Make one or more cohesive commits.
- Complete required repository checks. Rerun affected checks when subsequent
  edits invalidate earlier results; otherwise reuse the recorded results.
- Push the feature branch with tracking. Create a draft PR with base main,
  describing the final behavior, OpenSpec change, review outcome, verification,
  and material residual risk.
- Verify the pushed head, PR URL, source branch, base, and draft status. If a
  matching PR already exists on a resumed run, update it instead of duplicating it.

## Completion

Report the change, sync/archive status and location, local-only ignored artifacts,
both reviewer verdicts and rounds used, validation results, branch, commit, and PR
URL. All publishable work from this task must be committed and pushed.
If blocked, identify the last completed phase and the concrete prerequisite to
resume; do not report a partial run as complete.

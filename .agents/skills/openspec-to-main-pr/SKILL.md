---
name: openspec-to-main-pr
description: Drive a completed OpenSpec exploration through proposal, implementation, independent compliance review, an explicit delta-spec sync via $openspec-sync-specs, archive, intentional commit and push, and a draft pull request into main. Use from any Git repository when the user explicitly requests the complete OpenSpec-to-PR workflow in one pass.
---

# OpenSpec to Main PR

Orchestrate the complete delivery workflow after the user has finished an
`openspec-explore` discussion. Keep the phases ordered, and do not publish until
the OpenSpec artifacts, implementation, independent review, validation, main-spec
sync, and archive are complete.

The final operation creates a pull request from the working branch into `main`.
Never merge the pull request or push directly to `main`.

## Worktree isolation (must happen first)

Before doing any other workflow work—including reading or writing OpenSpec
artifacts, selecting a store, or creating a branch—inspect the current repository:

1. Run `git status --short --branch` and identify the current branch.
2. If the current branch is `main`, or `git status --porcelain` returns any output
   (staged, unstaged, or untracked changes), create a new worktree before
   continuing.
3. Create the worktree from the current `HEAD` on a new focused branch, such as
   `codex/<description>`, then change the working directory to that worktree.
4. Run the remaining phases entirely from the new worktree. Leave the original
   worktree and any uncommitted changes untouched; do not stash, reset, or commit
   them as part of this workflow.
5. If the worktree or branch cannot be created safely, stop and report the exact
   blocker.

If the current worktree is already on a focused non-`main` branch and is clean,
continue there. Never begin the OpenSpec workflow from `main` or from a dirty
worktree.

## Portability and prerequisites

- Run from the current Git repository. Do not assume a repository path, framework,
  OpenSpec schema, default branch, or project-local skill directory.
- Require a completed exploration. If the user is still brainstorming, remain in
  `$openspec-explore` instead of starting implementation.
- Require the `openspec` CLI and discoverable OpenSpec skills by name:
  `$openspec-propose`, `$openspec-sync-specs`, and
  `$openspec-archive-change`, plus preferably `$openspec-apply-review`. If
  `$openspec-apply-review` is unavailable, use `$openspec-apply-change` followed
  by an independent read-only compliance review when subagent support is
  available. If a required capability is unavailable, stop and report it.
- Resolve those skills by name from the active project or global installation. Do
  not reference `.codex/skills`, `.agents/skills`, or another absolute path.
- If a named OpenSpec store is in use, run `openspec store list --json`, select the
  intended store, and pass its `--store` value to every applicable OpenSpec command.
  Otherwise use the nearest local OpenSpec root.

## Operating rules

- Treat the completed exploration conversation as the source of intent. Do not
  restart exploration unless the requirements remain materially unclear.
- Run phases in this order:
  1. `$openspec-propose`
  2. `$openspec-apply-review` (or apply plus independent review fallback)
  3. `$openspec-sync-specs`
  4. `$openspec-archive-change`
  5. Publish a draft PR targeting `main`
- Continue to the next phase automatically after a phase skill hands off
  successfully. A standalone planning skill may say to stop after creating its
  artifacts; in this orchestrated workflow, treat that successful handoff as the
  end of the phase and continue. Stop for actual blockers.
- Preserve unrelated user changes. Never use `git add -A` when ownership or scope
  is unclear.
- Record the final OpenSpec status, review verdict, changed-file scope, and exact
  validation results before publishing.

## 1. Establish the change and preflight

Use the requirement and decisions already established during exploration. Derive
a concise kebab-case change name only when the conversation does not provide one.

Before writing or implementing anything:

1. Run `git status -sb` and identify the current branch.
2. Select the OpenSpec store if applicable, then run `openspec list --json`.
3. Read `openspec/config.yaml` or `config.yml` when present. Treat its context and
   rules as constraints for the artifacts; do not copy them into the artifacts.
4. If a matching active change exists, inspect its status and artifacts. Do not
   create a duplicate or overwrite existing work. Continue only when its intent
   matches the completed exploration.
5. If there is no usable requirement or change name, stop and ask for the missing
   description.

## 2. Generate the OpenSpec proposal

Invoke `$openspec-propose` with the change name and the consolidated exploration
outcome. Let that skill follow the repository's schema and artifact instructions;
do not invent artifact paths.

Require the proposal phase to:

- create every artifact transitively required for apply, not only `tasks.md`;
- read dependency artifacts before creating dependent artifacts;
- honor project context and artifact-specific rules;
- complete missing artifacts without duplicating or discarding existing work; and
- verify `openspec status --change "<name>"` before implementation.

Do not continue while the proposal is incomplete, the change is ambiguous, or the
OpenSpec CLI reports a blocked required artifact.

## 3. Implement and independently review

Invoke `$openspec-apply-review` for the same change name when available. It must
run the normal `$openspec-apply-change` flow first and then dispatch a read-only
compliance reviewer. If the review skill is not available, run the apply skill and
dispatch the equivalent independent review yourself; do not silently replace the
independent review with a self-review.

Require this phase to:

- read all `contextFiles` returned by
  `openspec instructions apply --change "<name>" --json`;
- implement every pending task and mark completed tasks in the tasks artifact;
- run the most relevant project tests, checks, or build commands;
- confirm apply state is `all_done` or that every task is complete;
- give the reviewer the OpenSpec context files, changed-file scope, completed-task
  summary, and validation results;
- keep the reviewer read-only; and
- fix valid findings in the primary worktree, then rerun targeted checks and the
  compliance review after any material behavior change.

Do not publish when the reviewer reports a blocking or unresolved compliance issue.
Capture the reviewer verdict and any residual risk.

## 4. Synchronize the main specs

Enter this phase only after apply, review, and validation are complete or any
non-blocking limitation is explicitly understood.

Invoke `$openspec-sync-specs` for the same change name. This is a separate required
phase; do not rely on `$openspec-archive-change` to perform the sync inline.

Require the sync phase to:

- use the selected OpenSpec store/root and `artifactPaths.specs.existingOutputPaths`
  from the change status, without inferring delta paths from unrelated artifacts;
- intelligently merge every selected delta requirement and scenario into its
  corresponding main spec while preserving content not mentioned by the delta;
- run `openspec validate --specs` with the same selected-root flags; and
- report the updated capabilities, changes made, validation result, and changed-file
  scope before handing off to archive.

If no delta specs exist, treat the sync as a successful no-op after the sync skill
confirms that there is nothing to write, then continue to archive. If sync reports
an ambiguous change, merge conflict, invalid instructions, write failure, or
validation failure, stop before archiving and report the exact blocker.

Leave the change active after this phase. Do not archive it yet.

## 5. Archive the synchronized change

Enter this phase only after `$openspec-sync-specs` succeeds or confirms a valid
no-op.

Invoke `$openspec-archive-change` for the same change name before committing or
publishing. Because synchronization already happened in the previous phase, the
archive phase must:

- verify every delta requirement and scenario is represented by the corresponding
  main spec;
- reject or report any remaining unsynchronized delta instead of silently performing
  the sync as a substitute for `$openspec-sync-specs`;
- provide the completed sync summary to the archive workflow and choose its
  `Archive now` path only when every delta is already synced; never choose `Sync
  now` or `Sync anyway` inside archive. If archive reports changes still needed,
  stop and rerun `$openspec-sync-specs` as the separate phase;
- validate the synchronized main spec and completed change artifacts;
- move the complete change directory, including `.openspec.yaml` when present, to
  the dated archive location; and
- verify that the active-change path is gone, the archive is complete, and all sync
  and archive files are in the intended changed-file scope.

If an unsynchronized delta remains, synchronization conflicts, the archive target
already exists, or the archive cannot be verified, stop before publishing and report
the exact blocker.

## 6. Commit, push, and create the PR to `main`

Enter this phase only after apply, review, validation, main-spec synchronization,
and archive are complete.

Recheck:

- `git status -sb`
- `git diff --stat`
- `git diff --name-only`

Resolve the repository from `origin`. Confirm that the remote has a `main` branch;
the PR target is always `main`, even if the repository has another default branch.

Use `$yeet` when it is available and can honor the explicit `main` target. Otherwise
use a write-capable GitHub connector if available. Use the local CLI path only when
both `gh --version` and `gh auth status` succeed. If none of these publish paths is
available, stop and report the missing capability.

### Source branch and local CLI path

1. Confirm that the worktree-isolation rule has been satisfied. If the current
   worktree is still `main` or contains uncommitted changes, stop and establish the
   isolated worktree before staging.
2. Keep an existing focused feature branch when its scope is clear; otherwise use
   the focused branch created by the isolation rule.
3. Stage only files belonging to this OpenSpec change, including synchronized main
   specs and archive files. Group the in-scope files into one or more coherent
   commits when that makes different features or purposes easier to review. Keep
   each commit focused, and do not mix unrelated changes; if unrelated changes
   cannot be separated safely, stop and ask the user to identify the scope.
4. Rerun relevant checks if implementation or review fixes changed files after the
   earlier validation.
5. Create the intentional commit or commits with terse, purpose-specific
   descriptions. Review the staged diff before each commit, and ensure the
   complete ordered commit series represents the OpenSpec change.
6. Push the current branch with tracking to `origin` after all intended commits
   are created.
7. Create a draft PR with base `main`, the pushed source branch, and a body covering
   what changed, why, user/developer impact, the OpenSpec change name, review
   verdict, validation commands/results, and residual risk.

### GitHub connector path

When the local CLI is unavailable but the connector can write, perform the
equivalent remote operation without modifying `main`:

1. Resolve the repository, the `main` commit, and its base tree.
2. Create a focused source branch from the `main` commit.
3. Create blobs and trees for the changed text files, then create one or more
   focused commits in logical order when different features or purposes should
   be separated. Base each later commit on the preceding commit and move the
   source branch to the latest commit.
4. Verify the complete remote commit series against `main`.
5. Create a draft PR with `base: "main"`, the source branch, title, body, and
   validation details.

Use the connector's actual available actions and schemas; do not invent tool names
or claim success until the response includes a PR URL or stable identifier.

Never merge the PR, resolve reviews, or update `main` directly.

## Completion report

Report one concise handoff containing:

- OpenSpec change name and final artifact/apply status;
- main-spec synchronization and archive path/status;
- implementation and independent-review verdict;
- validation commands and results;
- source branch, commit, and PR URL/number; and
- residual risk or follow-up needed before merge.

If the workflow stops, report the last completed phase, the exact blocker, and the
smallest next action needed to resume. Do not present a partial run as a completed
PR workflow.

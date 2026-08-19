## Context

`~/.agents/skills` is the active user-level skill directory. It contains
maintained Markdown instructions plus one skill UI metadata file, while
`~/.agents/.skill-lock.json` is generated installation state. The repository
already has a separate `.codex/skills` copy, but that copy is older and is not
the active source. See `proposal.md` and the `managed-agent-skills` spec for the
intended behavior.

## Goals / Non-Goals

**Goals:**

- Make `.cider/.agents/skills` the single maintained source for the current
  user-level skills.
- Preserve the existing `~/.agents/skills` lookup path through a directory link
  while leaving the local lock file at `~/.agents/.skill-lock.json`.
- Make activation idempotent, verifiable, and recoverable when an existing real
  skill directory is present.
- Remove the stale repository `.codex` copy after the new source is verified.

**Non-Goals:**

- Do not manage `~/.codex`, its credentials, caches, runtime state, or the
  unrelated `~/.codex/skills/grill-me` skill.
- Do not manage project-local `.agents` directories or the existing Claude
  configuration.
- Do not commit generated lock metadata or make the generic symlink helper
  responsible for the special `.agents` migration.

## Decisions

### Keep the `.agents` root local and link only `skills`

The managed source will live at `.cider/.agents/skills`, and activation will
ensure that `~/.agents/skills` is a symlink to that directory. The `~/.agents`
root remains a normal local directory so `.skill-lock.json` can remain outside
the repository. Linking the whole root was rejected because it would couple
generated installation state to the dotfiles checkout.

### Use a dedicated activation script

Add a focused setup entry point under `.cider/scripts` for this migration rather
than extending the generic `symlinks.sh` helper. The generic helper removes
existing targets and does not provide the backup, validation, and rollback
semantics required for a directory that contains local state beside the managed
skills.

The setup entry point will:

1. Resolve the repository-relative source and the user's `.agents` directory.
2. Verify that the source exists and contains the expected managed skill files.
3. If `~/.agents/skills` is already the correct link, report a no-op.
4. If it is a real directory or another link, move it to a timestamped,
   recoverable backup before creating the new link.
5. Validate the link and representative skill paths before reporting success.
6. Restore the previous path if link creation or validation fails.

The script will not alter `.skill-lock.json` and will not remove a backup as
part of a successful run.

### Copy the active source, then remove the stale parallel copy

During implementation, copy the current `~/.agents/skills` tree into
`.cider/.agents/skills`, retaining skill directories and maintained metadata but
excluding `.skill-lock.json` because it is outside the source tree. Compare the
result against the active files before deleting the tracked `.cider/.codex`
directory. The cleanup is limited to that repository path; it must not infer that
the separate `~/.codex` directory is obsolete.

### Keep activation explicit

Document and test the dedicated setup command without automatically invoking it
from `macos.sh` or the generic symlink runner. This keeps the migration's
destructive boundary explicit and avoids changing the behavior of unrelated
dotfile setup stages.

## Risks / Trade-offs

- [A user has local edits in `~/.agents/skills`] → move the directory to a
  timestamped backup before linking and document the backup path.
- [The repository source is incomplete] → validate expected files before
  replacing the active path and abort without touching the current installation.
- [A failed link or permission error leaves a partial migration] → perform
  validation immediately and restore the backup on failure.
- [The old `.cider/.codex` copy is still referenced by an undocumented workflow]
  → search repository references and verify the active skill root before removal.

## Migration Plan

1. Add the current maintained skills and metadata under `.cider/.agents/skills`.
2. Add and test the dedicated activation script in a temporary home fixture.
3. Run the script against the current account, retaining any backup it creates,
   and verify user-level skill discovery plus lock-file preservation.
4. Remove `.cider/.codex` from the repository and verify no in-scope references
   remain.
5. If activation must be rolled back, remove the managed link and restore the
   most recent migration backup to `~/.agents/skills`.

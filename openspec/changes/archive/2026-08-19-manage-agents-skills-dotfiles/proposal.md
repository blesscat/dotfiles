## Why

The active user-level skills under `~/.agents/skills` are not currently tracked by
the dotfiles repository, while `.cider/.codex/skills` contains an older parallel
copy that can drift from the installed skills. Making `.cider` the canonical
source for the reusable skill files will make them recoverable and reviewable
without versioning generated installation state.

## What Changes

- Add `.cider/.agents/skills` as the version-controlled source for the current
  user-level skills under `~/.agents/skills`.
- Preserve each skill's directory structure and any maintained metadata such as
  `agents/openai.yaml`.
- Keep `~/.agents/.skill-lock.json` as local installation state rather than
  committing it to the dotfiles repository.
- Link `~/.agents/skills` to `.cider/.agents/skills` using a safe, reversible
  activation flow that protects the current directory before replacement.
- Remove the obsolete `.cider/.codex` skill copy after verifying it is no longer
  needed, without changing the separate runtime state in `~/.codex`.
- Leave project-local skills such as `autoIQ/.agents` and unrelated Claude
  configuration outside this change.

## Capabilities

### New Capabilities

- `managed-agent-skills`: Provide a version-controlled canonical source and
  repeatable user-level activation for reusable skills stored under `~/.agents`.

### Modified Capabilities

None.

## Impact

- Adds the current user-level skill files to the `.cider` Git repository.
- Changes the user-level skill lookup path so `~/.agents/skills` resolves to the
  dotfiles source.
- Removes the stale `.cider/.codex` copy from the repository.
- Does not commit `.skill-lock.json`, credentials, caches, Codex runtime state,
  project-local skills, or unrelated configuration.

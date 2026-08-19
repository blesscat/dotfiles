## 1. Capture the active skill source

- [x] 1.1 Inventory the current `~/.agents/skills` tree, including all
  `SKILL.md` files and maintained metadata, and record the files that must not
  be copied such as `~/.agents/.skill-lock.json`.
- [x] 1.2 Search the repository for references to `.codex/skills` and confirm
  that removing `.cider/.codex` will not affect `~/.codex`, project-local
  `.agents` directories, or unrelated Claude configuration.
- [x] 1.3 Copy the current maintained user-level skill tree into
  `.cider/.agents/skills`, preserve its directory structure and metadata, and
  verify the copied file list and hashes before changing the active path.

## 2. Implement safe user-level activation

- [x] 2.1 Add a dedicated `.cider/scripts/agents_skills_setup.sh` entry point
  that resolves the repository source and user `.agents` directory without
  relying on the caller's current working directory.
- [x] 2.2 Implement source validation, correct-link no-op behavior, safe backup
  of an existing real or incorrect `~/.agents/skills` path, link creation, and
  post-activation validation while leaving `.skill-lock.json` untouched.
- [x] 2.3 Implement failure recovery so link or validation errors restore the
  previous skill path and report the backup or failure clearly.
- [x] 2.4 Add isolated temporary-home tests for a fresh install, an existing
  skill directory, an existing lock file, an already-correct link, an incorrect
  link, a source-validation failure, and a simulated activation failure.

## 3. Remove the obsolete parallel source and document usage

- [x] 3.1 Document the explicit activation command, canonical source path,
  local lock-file behavior, backup location, rollback procedure, and the fact
  that `macos.sh` and the generic symlink runner do not invoke this migration.
- [x] 3.2 After source and activation verification, remove the tracked
  `.cider/.codex` directory and confirm no repository reference still depends on
  it.
- [x] 3.3 Run the activation flow for the current account, confirm
  `~/.agents/skills` points to `.cider/.agents/skills`, and verify the lock file
  remains local and unchanged.

## 4. Validate scope and rollback safety

- [x] 4.1 Run shell syntax checks and the isolated activation test suite, then
  verify repeated activation is idempotent and preserves an existing backup.
- [x] 4.2 Verify `~/.codex`, the project-local `autoIQ/.agents`, and unrelated
  Claude configuration are unchanged; verify no lock file or runtime state is
  tracked by the `.cider` change.
- [x] 4.3 Run `git diff --check`, inspect `git status` and the changed-file list,
  and confirm the final OpenSpec change contains only the intended source,
  activation, documentation, cleanup, and planning files.

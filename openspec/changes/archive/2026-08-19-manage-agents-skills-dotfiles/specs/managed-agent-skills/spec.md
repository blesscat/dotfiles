## Purpose

Provide a recoverable, reviewable, and repeatable user-level skill installation
whose maintained source lives in the Cider dotfiles repository.

## ADDED Requirements

### Requirement: Canonical user skill source

The dotfiles setup SHALL treat `.agents/skills` in the Cider repository as the
canonical source for every reusable skill currently managed under the user's
`~/.agents/skills`, preserving each skill's directory structure and maintained
metadata.

#### Scenario: Activate the managed skills

- **WHEN** the dotfiles activation is completed successfully
- **THEN** `~/.agents/skills` resolves to the repository's `.agents/skills`
  source and all managed skills remain discoverable at their existing paths

### Requirement: Keep generated installation state local

The dotfiles source SHALL exclude `.skill-lock.json` and SHALL preserve the
user-level lock file as local installation state when activating the managed
skills.

#### Scenario: Activate skills with an existing lock file

- **WHEN** `~/.agents/.skill-lock.json` exists before activation
- **THEN** activation leaves that file outside the version-controlled source
  and does not overwrite it as part of the skill migration

### Requirement: Migrate safely and support rollback

The activation process SHALL protect an existing real `~/.agents/skills`
directory before replacing it with the managed source, and SHALL leave the
existing installation usable or recoverable if activation fails.

#### Scenario: Existing skills are migrated

- **WHEN** `~/.agents/skills` is a real directory containing user skills
- **THEN** the process preserves a recoverable copy or backup before activating
  the repository source

#### Scenario: Activation fails

- **WHEN** creating or validating the managed link fails
- **THEN** the process reports the failure and does not leave the user with an
  unusable or partially replaced skill installation

### Requirement: Remove the obsolete repository copy

The migration SHALL remove the tracked `.codex` skill copy from the Cider
repository after the managed `.agents/skills` source is verified, without
modifying the separate runtime state under `~/.codex`, project-local skills, or
unrelated Claude configuration.

#### Scenario: Repository cleanup completes

- **WHEN** the managed `.agents/skills` source has been verified
- **THEN** `.cider/.codex` is absent from the repository while `~/.codex` and
  project-local skill directories remain unchanged

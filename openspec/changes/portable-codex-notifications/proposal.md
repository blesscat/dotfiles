## Why

The Codex notification feature currently lives across unversioned files under one macOS home directory and contains user- and Homebrew-specific absolute paths. Moving its source and installation recipe into `.cider` makes the working behavior recoverable on a new Mac or under a different user account without committing Codex runtime state or a signed binary bundle.

## What Changes

- Add a version-controlled `codex-notify` module containing the completion wrapper, permission adapter, exact-click router, behavioral tests, fixtures, and maintained documentation.
- Replace user-specific and Apple-Silicon-specific paths with runtime discovery based on `$HOME`, `CODEX_HOME`, script-relative paths, `command -v`, and `brew --prefix`.
- Replace the JSON-driven macOS Homebrew lists with a repository-root `Brewfile` that declares the existing formulas and casks plus `jq` and `terminal-notifier`, then run an idempotent notification installer after `brew bundle` succeeds.
- Install runtime scripts as symlinks, reconstruct and ad-hoc sign the Terminal Notifier app from Homebrew, and verify the result before activation.
- Merge only the owned Codex notification keys and permission hook into user-level configuration while preserving unrelated settings, hooks, and local state.
- Back up replaced files, use staged writes, and restore or leave the previous installation intact when validation fails.
- Exclude authentication, logs, sessions, project trust, plugin state, hook trust hashes, and the generated app bundle from Git.

## Capabilities

### New Capabilities

- `codex-notifications`: Completion and permission notifications retain dynamic content, environment-based Ghostty/Terminal Notifier selection, default sound, and precise Zellij click routing.
- `codex-notification-bootstrap`: `.cider` can reproducibly install, merge, validate, back up, and restore the notification feature across macOS user accounts.

### Modified Capabilities

None. This is the first OpenSpec definition for these existing local behaviors.

## Impact

- Adds a new module and OpenSpec-managed documentation under `~/.cider`.
- Adds `.cider/Brewfile`, removes Homebrew package data from `.cider/bootstrap.json`, retires the superseded macOS formula/cask readers, and updates `.cider/macos.sh` to use `brew bundle --no-upgrade` while leaving symlink and after-script metadata in `bootstrap.json`.
- Makes the existing cask declarations active during macOS bootstrap: DaisyDisk, Scroll Reverser, Warp, and Ghostty are installed as casks; the obsolete `homebrew/cask-fonts` tap is not migrated.
- Replaces the current standalone files under `~/.local/bin` with symlinks to the repository module.
- Updates only the notification-related portions of `~/.codex/config.toml` and `~/.codex/hooks.json`; Codex will require the installed permission hook to be reviewed again through `/hooks` when its content hash changes.
- Depends on macOS, Homebrew, `jq`, `terminal-notifier`, `codesign`, Ghostty, and optionally Zellij for exact pane routing.

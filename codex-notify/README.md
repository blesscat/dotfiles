# Portable Codex notifications

This module is the maintained source for the three Codex notification runtime
scripts, their installer, behavior tests, fixtures, and design documentation.
Generated app bundles and mutable Codex state stay outside Git.

## What owns what

The repository-root `Brewfile` is the only macOS Homebrew dependency manifest.
It includes `jq` and `terminal-notifier`. Running `macos.sh` also installs the
four approved casks: DaisyDisk, Scroll Reverser, Warp, and Ghostty.

`bootstrap.json` continues to own the generic dotfile `symlinks` metadata used
by the existing workflow. `macos.sh` does not run the generic symlink runner.
The notification installer separately owns only:

- `~/.local/bin/codex-notify`
- `~/.local/bin/codex-permission-notify`
- `~/.local/bin/codex-notification-route`
- `~/.local/share/codex-notify/terminal-notifier.app`
- top-level `notify` and `[tui].notifications` in
  `${CODEX_HOME:-$HOME/.codex}/config.toml`
- one canonical `PermissionRequest` group in
  `${CODEX_HOME:-$HOME/.codex}/hooks.json`

All unrelated Codex configuration and hook handlers are preserved.

## Prerequisites and installation

The supported target is macOS. The full bootstrap first offers a verified,
default-no Determinate Nix installation when Nix is missing, installs Homebrew
when needed, runs the Brewfile without bulk upgrades, and invokes this
installer:

```sh
cd ~/.cider
./macos.sh
```

For a standalone notification install after Homebrew dependencies are ready:

```sh
cd ~/.cider
./codex-notify/install.zsh
```

Codex and Sky Computer Use are not installed by this repository. If either is
missing, the installer still creates the runtime symlinks and signed helper
app, leaves `config.toml` and `hooks.json` untouched, reports activation as
deferred, and prints the command to rerun later.

The runtime executables are symlinks into this repository. Keep `~/.cider`
available at the same location; after moving or replacing the clone, rerun the
installer.

## Local configuration safety

Before activating changes, the installer:

1. stages a Homebrew Terminal Notifier app, ad-hoc signs it, and requires a
   strict deep signature check;
2. narrowly merges the two owned TOML settings and the owned JSON hook;
3. validates the staged TOML with
   `codex --strict-config doctor --json --summary` under an isolated
   `CODEX_HOME`; and
4. groups every replaced target into one timestamped backup run.

Any TOML multiline string, an ambiguous multiline top-level `notify`, invalid
hook JSON, failed signature, or failed `config.load` check aborts before active
targets are replaced.
Changed hooks are never trusted automatically. After installation reports a
hook change, open Codex and review it through `/hooks`.

Backups live under:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/cider/backups/codex-notify/<run-id>/
```

Restore an explicitly selected run with:

```sh
cd ~/.cider
./codex-notify/install.zsh --rollback \
  "${XDG_STATE_HOME:-$HOME/.local/state}/cider/backups/codex-notify/<run-id>"
```

Each completed run records the installed state of every managed target.
Rollback refuses the entire operation if a script, app, config, or hooks file
has changed since that run, so later user edits are never overwritten. If it
refuses, preserve and manually reconcile those later edits before retrying;
do not expect a converged installer rerun to create a new snapshot.

## Verification

Run the isolated suites from the repository root:

```sh
/bin/zsh codex-notify/tests/codex-notify-test.zsh
/bin/zsh codex-notify/tests/portable-paths-test.zsh
/bin/zsh codex-notify/tests/installer-test.zsh
/bin/zsh codex-notify/tests/nix-setup-test.zsh
/bin/zsh codex-notify/tests/bootstrap-test.zsh
/bin/zsh codex-notify/tests/brewfile-test.zsh
/bin/zsh codex-notify/tests/yazelix-test.zsh
```

Verify a live installation with:

```sh
/bin/zsh codex-notify/tests/live-install-test.zsh
codex --strict-config doctor --json --summary
```

The doctor result is acceptable only when
`checks["config.load"].status` is `ok`. Finish with one plain Ghostty
completion click and one Zellij completion or permission click, then confirm a
permission hook still emits no stdout and never makes an approval decision.

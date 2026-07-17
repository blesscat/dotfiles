## Context

The working notification system is split across three executable scripts in `~/.local/bin`, a signed copy of Terminal Notifier in `~/.local/share`, Codex user configuration and hooks, tests under `~/.codex`, and historical design documents. The scripts and tests contain a specific user's home and Homebrew prefix, while `~/.codex/config.toml` also contains project trust, plugin state, hook trust hashes, and other machine-local data that must not become dotfiles source.

The `.cider` repository currently splits macOS Homebrew state across JSON lists and shell scripts: formulas are read from `bootstrap.json`, `jq` is installed separately in `macos.sh`, casks and the deprecated `homebrew/cask-fonts` tap are declared but not activated, and `terminal-notifier` is not declared. `ghostty` is listed as a formula even though Homebrew distributes it as a cask. The same JSON file also contains cross-platform symlink metadata plus an obsolete after-script runner. The generic symlink helper deletes complete targets, so notification links require their own installer. Codex requires the external `notify` command at user scope, so a project `.codex/config.toml` cannot replace an installer-managed merge into `$CODEX_HOME/config.toml`.

The repository currently has unrelated uncommitted fish, Ghostty, and Yazelix configuration changes. This change must not edit, stage, restore, or otherwise absorb those paths. A new standalone Yazelix setup script is in scope, but existing Yazelix configuration remains untouched.

## Goals / Non-Goals

**Goals:**

- Make `.cider` the canonical source for notification scripts, behavior tests, fixtures, and maintained documentation.
- Restore the feature under a different macOS user name and either standard Homebrew prefix.
- Make a repository-root `Brewfile` the single source for macOS Homebrew formulas and casks, including `jq` and `terminal-notifier`, while retaining only generic symlink metadata in `bootstrap.json`.
- Install the approved shell and workspace tools through Homebrew, offer an explicit verified Determinate Nix installation when Nix is missing, and make Yazelix installation repeatable.
- Preserve every unrelated Codex setting and hook while managing only the notification-owned entries.
- Make installation repeatable, failure-safe, and testable without mutating the real home directory.
- Preserve the verified completion, permission, sound, backend-selection, and click-routing behavior.

**Non-Goals:**

- Version Codex authentication, sessions, logs, caches, project trust, plugin state, or hook trust hashes.
- Commit the Homebrew Terminal Notifier app bundle or another generated binary.
- Install Codex or Sky Computer Use itself.
- Install or replace Nix without explicit user confirmation, migrate an existing upstream Nix installation, remove Nix, or automatically launch Yazelix.
- Replace `.cider`'s generic dotfile symlink system or clean up unrelated existing files.
- Automatically trust a user hook or bypass Codex hook review.
- Add Linux support for the macOS Notification Center feature.

## Decisions

### Use a self-contained repository module

Create `codex-notify/` with `bin/`, `tests/`, `docs/`, and `install.zsh`. The installer links the three runtime executables into `~/.local/bin`; tests and documentation remain repository-only.

This keeps all related sources reviewable together and avoids teaching the generic symlink helper how to partially manage Codex state. Placing the scripts directly in `symlinks/.local/bin` was considered, but it would scatter installer, tests, and documentation across the repository. Symlinking all of `~/.codex` was rejected because that directory contains credentials and mutable runtime state.

### Use Brewfile for Homebrew dependencies and keep dotfile metadata separate

Create a repository-root `Brewfile` as the only macOS Homebrew dependency manifest. Move the existing formula and cask declarations out of `bootstrap.json`, add `jq` and `terminal-notifier` as formulas, and classify Ghostty as a cask. The previously dormant DaisyDisk, Scroll Reverser, and Warp casks become part of the automatic macOS bootstrap by explicit user choice. Do not migrate `homebrew/cask-fonts`: Homebrew deprecated the tap, its contents moved to the main cask repository, and this repository declares no font casks that require it.

The manifest contains exactly these declarations:

```ruby
brew "bash"
brew "zlib"
brew "openssl"
brew "cmake"
brew "ctags"
brew "ssh-copy-id"
brew "ripgrep"
brew "fzf"
brew "node"
brew "git"
brew "lazygit"
brew "wget"
brew "neovim"
brew "helix"
brew "mosh"
brew "unzip"
brew "yazi"
brew "fish"
brew "starship"
brew "zoxide"
brew "atuin"
brew "pnpm"
brew "zellij"
brew "jq"
brew "terminal-notifier"

cask "daisydisk"
cask "scroll-reverser"
cask "warp"
cask "ghostty"
```

Keep `bootstrap.json` for the existing generic `symlinks` data, and remove the obsolete root `after_script.sh` runner and its metadata. Retire the root macOS `install_formulas.sh` and `install_casks.sh` readers instead of leaving a second package source. `macos.sh` resolves repository-relative paths, runs Homebrew setup, discovers the resulting `brew` through the current `PATH` or the standard Apple Silicon and Intel installation locations, evaluates that executable's `shellenv` when needed, runs `brew bundle install --file=<repo>/Brewfile --no-upgrade`, and executes `codex-notify/install.zsh` only after the bundle succeeds. `--no-upgrade` preserves the current install-without-bulk-upgrade behavior. Missing Homebrew or a bundle failure stops notification setup. The generic symlink runner remains opt-in and is not invoked by `macos.sh`.

The notification installer performs a preflight and uses `command -v brew` plus `brew --prefix terminal-notifier`; it does not assume a fixed Homebrew prefix. When Codex or Sky Computer Use is not installed yet, bootstrap reports that Codex configuration is deferred and prints the command to rerun instead of writing a broken notifier path.

### Offer verified Determinate Nix installation before Homebrew

After repository preflight and before Homebrew setup, `macos.sh` runs `scripts/nix_setup.sh`. An existing `nix` command is user-owned state: setup reports its version without prompting, reinstalling, migrating, or rewriting its configuration. When Nix is missing, setup explains that Determinate Nix creates `/nix`, installs a daemon, and requires administrator authorization, then asks `Install Determinate Nix now? [y/N]`.

Case-insensitive `y` and `yes` approve installation. `n`, `no`, an empty response, or end-of-file declines without failing the remaining macOS bootstrap; invalid interactive input prompts again. This default-no behavior prevents unattended execution from silently making privileged system changes. Once a user approves, any download, provenance, package installation, environment activation, version, or flakes failure is fatal before Homebrew begins.

Download Determinate Systems' stable Universal macOS package from `https://install.determinate.systems/determinate-pkg/stable/Universal` into a private temporary directory using HTTPS-only curl options. Validate the package with macOS package assessment and require Apple Developer Team ID `X3JQ4VPJZ6` before invoking the system installer through `sudo`. Always clean up the staged package. Directly piping a remote shell into an interpreter was rejected because a partial or changed download could execute before local package provenance is assessed. A manually downloaded installer was rejected because it would not meet the new-Mac automation goal.

The production entrypoint fixes the repository helper, `/usr/bin/curl`, `/usr/sbin/spctl`, `/usr/bin/sudo`, `/usr/sbin/installer`, and the standard `/nix` daemon profile instead of selecting them from inherited environment variables. Isolated tests call the shared implementation through a test-only harness with explicit fixture paths. This keeps dry runs non-privileged without allowing a caller's ambient environment to replace the production provenance or installer boundary.

The setup script verifies the installed Nix executable, version, and flake command. Because a child script cannot modify its parent's environment, `macos.sh` sources the standard Nix daemon profile if necessary and requires `command -v nix` to succeed before continuing after an approved installation. The repository does not automate uninstallation or remove `/nix`, daemons, system users, volumes, or Keychain state.

### Install Yazelix through Nix without taking over first launch

Yazelix is not a Homebrew dependency. After the Brewfile and notification installer succeed, `macos.sh` runs `scripts/yazelix_setup.sh`. The script is idempotent: an existing `yzx` command is a no-op; otherwise, when Nix is available, it runs `nix profile add --refresh github:luccahuguet/yazelix`. Nix remains missing only when installation was declined or unavailable before approval; that condition defers Yazelix and exits successfully so the completed Homebrew and notification setup is not retroactively treated as failed. An actual Nix or Yazelix installation failure after approval remains fatal and visible.

The setup script does not install Nix and never runs `yzx launch`. First launch is intentionally left until after the separate generic symlink step because Yazelix may interactively update editor configuration. The documented new-Mac flow ends with `./symlinks.sh` followed by `yzx launch`.

### Resolve runtime paths instead of templating source files

Source-controlled scripts derive locations from `$HOME`, `${CODEX_HOME:-$HOME/.codex}`, their resolved script directory, `command -v jq`, and environment overrides already used by tests. Zellij remains resolved to an absolute executable at notification creation time so later clicks do not depend on an interactive shell or NVM.

Codex configuration requires concrete argv strings, so the installer renders the current absolute `$CODEX_HOME`, Sky client, and installed wrapper paths only into the local config and hook files. Those generated values are never copied back into Git.

### Merge only explicitly owned configuration

The installer owns exactly three settings:

- top-level `notify`, pointing to Sky with `codex-notify --native-only` as its previous notifier;
- `notifications = false` inside `[tui]`;
- one `PermissionRequest` matcher group whose command is the installed `codex-permission-notify` path.

A narrow TOML merger preserves all other text and refuses input containing TOML multiline strings or an ambiguous owned value it cannot safely distinguish with a line-oriented edit. It writes a temporary candidate and requires the `config.load` check from `codex --strict-config doctor --json --summary` to report `ok` before replacing the real file. JSON hook merging uses `jq`, removes or updates only handlers that target `codex-permission-notify`, retains all other groups and handlers, and ensures exactly one canonical owned group.

Tracking a complete `config.toml` was rejected because it would capture changing project and plugin state. Re-serializing the entire TOML with a general converter was rejected because it would create noisy unrelated diffs and discard formatting or comments.

### Stage generated artifacts and back up every replaced target

Before changing an existing runtime script, app bundle, config, or hook file, store its prior state under `${XDG_STATE_HOME:-$HOME/.local/state}/cider/backups/codex-notify/<timestamp>/`. Build the app bundle in a temporary sibling path using the Homebrew source, apply ad-hoc signing, and require `codesign --verify --deep --strict` before an atomic rename. Treat an existing app as current only when it is a real directory, matches the stage, and independently passes the same strict signature check.

Configuration candidates are also written beside their targets and atomically renamed only after validation. Preflight runs before mutation, and a failed step either leaves the old target untouched or restores the backup created by that run. A completed backup records post-install fingerprints for every managed target; explicit rollback validates the fixed manifest mapping and refuses atomically if any target has drifted since installation. Re-running an already-current installation produces no duplicate hooks and does not create needless backups.

### Preserve runtime notification semantics

Portability refactors may change path discovery but not event behavior. Plain Ghostty completion and permission events use OSC 9 on the originating tty; Zellij uses signed Terminal Notifier with `-sound default` and an opaque exact-route token; tty or route failures stay non-blocking and fall back to activating Ghostty. Sky receives each completion once, while permission events never call Sky or return an approval decision.

### Test the installer with isolated homes

Refactor the existing behavior suite to derive module paths and keep dependency overrides. Add installer tests that use temporary `HOME`, `CODEX_HOME`, state, Homebrew prefix, app bundle, and command fixtures. Tests cover clean install, migration, idempotent rerun, preservation of unrelated TOML and hooks, different home paths, deferred Codex configuration, staged-signing failure, invalid merged config, and rollback. Add bootstrap orchestration tests whose fake `brew` records the observable `bundle` argv and failure status, and use `brew bundle list` to validate the Brewfile's formula/cask classification without installing packages. Assertions inspect files, links, argv, parsed manifests, JSON, OSC bytes, exit status, and backups rather than implementation source text.

## Risks / Trade-offs

- **Narrow TOML editing cannot safely distinguish keys inside TOML multiline strings** → Reject configs containing multiline strings before mutation and report manual remediation rather than risk corrupting unrelated text.
- **Runtime symlinks depend on `~/.cider` remaining available** → Treat that location as the dotfiles contract, verify link targets on each run, and document rerunning the installer after moving the repository.
- **Homebrew can ship a different Terminal Notifier build** → Resolve the formula prefix dynamically, sign a staged copy, run strict code-sign verification, and retain the last working bundle on failure.
- **`brew bundle` upgrades dependencies by default** → Always invoke it with `--no-upgrade`; test the recorded argv so bootstrap cannot silently become a bulk-upgrade operation.
- **Previously dormant casks become automatic installs** → Keep the four approved casks explicit in the Brewfile and document that running `macos.sh` installs them; do not run `brew bundle cleanup` or remove unrelated installed software.
- **Homebrew manifest migration can preserve stale classifications** → Omit the deprecated `homebrew/cask-fonts` tap, classify Ghostty as a cask, and validate the manifest through `brew bundle list` before live bootstrap.
- **Installing Nix changes system state and requires administrator access** → Explain `/nix` and daemon changes, default the prompt to no, accept EOF as no, validate the signed package before `sudo`, and stop before Homebrew on an approved-install failure.
- **The stable package endpoint can change its payload over time** → Require HTTPS-only download plus Apple Developer Team ID `X3JQ4VPJZ6`; reject missing or mismatched provenance before privileged installation.
- **Yazelix requires Nix with flakes and has an interactive first launch** → Offer Determinate Nix with flakes before Homebrew, defer when the user declines, and leave `yzx launch` as an explicit post-symlink step.
- **Codex may require hook trust again after path or content changes** → Never copy trust hashes; print an explicit `/hooks` review step after a changed hook installation.
- **Sky Computer Use may not exist when macOS bootstrap first runs** → Defer only Codex config/hook activation, avoid writing a broken `notify` command, and make a later installer run complete the setup.
- **A generic install can accidentally mix unrelated dirty work** → Restrict edits and staging to the new module, OpenSpec paths, `Brewfile`, `bootstrap.json`, the retired root Homebrew readers, `macos.sh`, and the new Yazelix setup script; leave existing Ghostty and Yazelix configuration paths untouched.

## Migration Plan

1. Record current script permissions and run the established notification behavior suite as a baseline.
2. Copy the maintained scripts, tests, fixtures, and documents into `codex-notify/`, then make path discovery portable under test before changing live targets.
3. Create the Brewfile, migrate and correctly classify the Homebrew declarations, remove the Homebrew and obsolete after-script data from `bootstrap.json`, retire the redundant macOS readers and `after_script.sh`, and call the module installer from `macos.sh` only after `brew bundle --no-upgrade` succeeds without enabling the generic symlink runner.
4. Add isolated behavior tests and an interactive signed-package Determinate Nix setup before Homebrew, preserving existing Nix and default-no deferral.
5. Add the idempotent Yazelix setup script after notification installation, deferring cleanly when Nix installation was declined and leaving first launch explicit.
6. Build installer behavior tests around temporary home directories and make clean install, merge, idempotence, failure, and rollback cases pass.
7. Run the installer against the current account. It backs up existing standalone files, replaces runtime executables with repository symlinks, reconstructs the signed app, and converges the two Codex configuration files.
8. Run strict syntax, behavior, installer, code-sign, Codex config-load, OpenSpec, and live completion/permission click checks.
9. Review the changed permission hook through `/hooks`, then commit only the notification/OpenSpec/bootstrap paths after inspecting the existing dirty worktree.

Rollback restores a selected installer backup for config, hooks, runtime scripts, and app bundle only while every managed target still matches that run's recorded post-install state. Drift causes an all-or-nothing refusal so later user edits cannot be lost. Because bootstrap changes are source-controlled separately, they can be reverted without deleting the last working installed artifacts.

## Open Questions

None. The approved choices are portable cross-user installation, incremental configuration merge, Homebrew reconstruction instead of binary versioning, a repository-root Brewfile for all macOS Homebrew dependencies, retention of generic symlink metadata only in `bootstrap.json`, removal of the obsolete after-script runner, activation of the declared casks, automatic notification-installer invocation after a successful bundle, interactive default-no Determinate Nix installation from a signed package before Homebrew, and non-interactive Yazelix profile installation without automatic first launch.

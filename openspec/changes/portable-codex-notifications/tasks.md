## 1. Baseline and module layout

- [ ] 1.1 Record the current `.cider` dirty paths, runtime script modes and hashes, installed app signature, notification config/hook shape, and a passing result from the existing behavior suite.
- [ ] 1.2 Create `codex-notify/bin`, `codex-notify/tests/fixtures`, and `codex-notify/docs`, then copy the maintained scripts, fixtures, behavior suite, and notification documents without changing the live installation.
- [ ] 1.3 Make the repository behavior suite derive module and installed paths from its own location or explicit overrides, and confirm the existing notification cases still pass before portability changes.

## 2. Portable runtime paths

- [ ] 2.1 Add behavior tests that execute module scripts through a temporary home, custom `CODEX_HOME`, non-default-prefix `jq`, and installed symlinks without relying on a fixed user home or Homebrew prefix.
- [ ] 2.2 Run the new portability cases and confirm they fail for the expected hard-coded-path behavior while established content, backend, sound, permission, and route cases remain green.
- [ ] 2.3 Refactor the completion wrapper, permission adapter, and route helper to resolve `$HOME`, `CODEX_HOME`, sibling scripts, `jq`, logs, app bundle, and Zellij paths at runtime while preserving all existing environment overrides.
- [ ] 2.4 Run syntax checks and the complete runtime behavior suite until portable and established cases pass with clean output.

## 3. Installer foundations and generated app

- [ ] 3.1 Add installer fixtures and behavior tests for prerequisite discovery, clean executable symlink creation, migration from standalone files, already-current symlinks, Homebrew formula prefix discovery, staged app signing, and signature failure.
- [ ] 3.2 Run the installer cases and confirm they fail because `codex-notify/install.zsh` does not yet provide the required behavior.
- [ ] 3.3 Implement installer preflight, target directory creation, timestamped run state, managed executable symlinks, Homebrew app staging, ad-hoc signing, strict deep signature verification, and atomic app activation.
- [ ] 3.4 Run the installer suite and confirm successful installs converge while failed copy or signing cases retain the previous active files.

## 4. Safe Codex configuration and rollback

- [ ] 4.1 Add isolated-home tests for preserving unrelated TOML text, inserting and replacing the two owned settings, rejecting ambiguous multiline `notify`, checking staged `config.load`, retaining unrelated hook handlers, converging duplicate owned handlers, deferred Codex/Sky activation, grouped backups, idempotent reruns, and rollback.
- [ ] 4.2 Run the new merge and recovery cases and verify RED without mutating the real `HOME` or `CODEX_HOME`.
- [ ] 4.3 Implement the narrow TOML merger, `jq` hook merger, staged Codex validation, deferred bootstrap result, change-aware backups, atomic replacement, `/hooks` review notice, and an explicit rollback operation for a selected backup run.
- [ ] 4.4 Run the isolated installer suite twice and confirm all merge, preservation, deferral, backup, failure, rollback, and no-op idempotence cases pass.

## 5. Brewfile migration and macOS bootstrap integration

- [ ] 5.1 Add behavior tests that run the macOS bootstrap with command fixtures and assert the recorded sequence is Homebrew setup, Homebrew discovery/shell environment setup when `brew` is initially absent from `PATH`, `brew bundle install --file=<repo>/Brewfile --no-upgrade`, then `codex-notify/install.zsh`; assert missing Homebrew or a failed bundle prevents installer execution and neither the generic symlink runner nor Node/Neovim after-scripts run.
- [ ] 5.2 Add manifest contract tests that invoke `brew bundle list` against the proposed Brewfile and require exactly these formulas: `bash`, `zlib`, `openssl`, `cmake`, `ctags`, `ssh-copy-id`, `ripgrep`, `fzf`, `node`, `git`, `wget`, `neovim`, `mosh`, `unzip`, `yazi`, `fish`, `jq`, and `terminal-notifier`; exactly these casks: `daisydisk`, `scroll-reverser`, `warp`, and `ghostty`; and no taps. Run the orchestration and manifest cases and confirm RED against the current JSON-driven bootstrap.
- [ ] 5.3 Create the repository-root `Brewfile` with the exact declarations from 5.2; remove `formulas`, `casks`, and `taps` from `bootstrap.json` while preserving `symlinks` and `after-scripts`; retire the root `install_formulas.sh` and `install_casks.sh`; and update `macos.sh` to resolve repository paths, discover Homebrew after setup on both standard prefixes, apply `brew shellenv` when needed, stop on missing Homebrew or bundle failure, and invoke the notification installer only after bundle success without enabling generic symlink or after-script runners.
- [ ] 5.4 Run `plutil -lint bootstrap.json`, `brew bundle list --file=./Brewfile`, shell syntax checks, bootstrap orchestration tests, installer tests, and the runtime behavior suite; verify the second bootstrap fixture run is convergent and still records `--no-upgrade` without duplicate installer invocation.

## 6. Current-account migration and live verification

- [ ] 6.1 Run the installer for the current account and verify it backs up standalone notification files, installs the three repository symlinks, reconstructs a valid signed app, and changes only the owned Codex config and hook entries.
- [ ] 6.2 Run `codex --strict-config doctor --json --summary` and require the `config.load` check to report `ok`; verify exactly one canonical permission notification handler and no committed hook trust state.
- [ ] 6.3 Re-run all automated suites against the live installed paths, then test one plain Ghostty completion click and one Zellij completion or permission click with dynamic content and the expected default sound.
- [ ] 6.4 Review and trust the changed user hook through `/hooks`, then repeat a permission prompt to confirm notification delivery does not alter the approval decision or hook stdout.

## 7. Documentation, validation, and Git hygiene

- [ ] 7.1 Document Brewfile ownership of Homebrew dependencies, automatic installation of the four declared casks, retained `bootstrap.json` symlink/after-script ownership, bootstrap prerequisites, automatic and standalone notification installation, deferred activation, `/hooks` review, verification commands, backup location, rollback, and the requirement that `~/.cider` remain available for runtime symlinks.
- [ ] 7.2 Scan the notification module and staged paths for personal home paths, fixed Homebrew prefixes, credentials, Codex mutable state, generated backups, and app bundle contents; remove any unintended Git material.
- [ ] 7.3 Run strict OpenSpec validation and all syntax, runtime, installer, orchestration, signature, and Codex config-load checks from a clean command invocation.
- [ ] 7.4 Inspect `git diff` and `git status`, confirm the pre-existing fish, Ghostty configuration, and Yazelix changes are untouched, and stage or commit only the OpenSpec, notification module, `Brewfile`, `bootstrap.json`, retired root Homebrew readers, and `macos.sh` paths when the user approves publication.

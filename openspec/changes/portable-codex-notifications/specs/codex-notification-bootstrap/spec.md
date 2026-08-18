## ADDED Requirements

### Requirement: The repository is the portable source of truth
The `.cider` repository SHALL contain the maintained notification scripts, tests, fixtures, installer, and documentation while excluding generated binaries and mutable Codex state.

#### Scenario: Repository is cloned for a new user
- **WHEN** a user clones `.cider` under a different macOS home directory
- **THEN** all source artifacts needed to reconstruct the feature are present without a fixed user home or Homebrew prefix

#### Scenario: Repository content is inspected before push
- **WHEN** notification paths are staged for Git
- **THEN** they contain no `auth.json`, sessions, logs, caches, project trust, plugin state, hook trust hashes, backup data, or Terminal Notifier app bundle

### Requirement: Brewfile is the macOS Homebrew source of truth
The repository SHALL declare all macOS Homebrew formulas and casks in a root `Brewfile`, including the approved shell and workspace tools, `jq`, and `terminal-notifier` as formulas and Ghostty as a cask. `bootstrap.json` SHALL retain only generic symlink metadata and contain no Homebrew package lists or obsolete after-script metadata. The macOS bootstrap SHALL run the Brewfile with upgrades disabled, then invoke the notification installer and Yazelix setup only after bundle installation succeeds, without enabling the generic symlink runner.

#### Scenario: macOS bootstrap runs on a prepared machine
- **WHEN** `macos.sh` completes Homebrew setup
- **THEN** it runs `brew bundle install` against the repository Brewfile with `--no-upgrade`, the declared tools become available, `codex-notify/install.zsh` executes afterward, and Yazelix setup runs last

#### Scenario: Brewfile preserves and corrects the declared dependency set
- **WHEN** the Brewfile is inspected through `brew bundle list`
- **THEN** its formulas are exactly `bash`, `zlib`, `openssl`, `cmake`, `ctags`, `ssh-copy-id`, `ripgrep`, `fzf`, `node`, `git`, `lazygit`, `wget`, `neovim`, `helix`, `mosh`, `unzip`, `yazi`, `fish`, `starship`, `zoxide`, `atuin`, `pnpm`, `zellij`, `jq`, and `terminal-notifier`; its casks are exactly `daisydisk`, `scroll-reverser`, `warp`, and `ghostty`; and it declares no taps

#### Scenario: Homebrew was just installed on a new Mac
- **WHEN** Homebrew setup succeeds but `brew` is not yet available through the inherited `PATH`
- **THEN** `macos.sh` discovers the executable from a standard Apple Silicon or Intel Homebrew installation, applies its `shellenv`, and continues with the bundle

#### Scenario: Homebrew remains unavailable
- **WHEN** setup finishes without a discoverable executable
- **THEN** `macos.sh` exits unsuccessfully before bundle or notification installation

#### Scenario: Bundle installation fails
- **WHEN** `brew bundle install` exits unsuccessfully
- **THEN** `macos.sh` exits unsuccessfully without invoking `codex-notify/install.zsh` or Yazelix setup

#### Scenario: Dotfile symlink metadata remains separate
- **WHEN** Homebrew declarations move to the Brewfile
- **THEN** the existing `symlinks` values remain in `bootstrap.json`, no Homebrew formula, cask, tap, or after-script list remains there, and the obsolete after-script runner is absent

#### Scenario: Generic symlink setup remains opt-in
- **WHEN** notification bootstrap integration is added
- **THEN** the generic symlink runner is not enabled and no dotfile replacement is triggered as a side effect

### Requirement: Determinate Nix installation is explicit and provenance-checked
Before Homebrew setup, the macOS bootstrap SHALL preserve an existing Nix installation or, when Nix is missing, explain the system changes and ask for explicit confirmation before installing Determinate Nix. A declined or unavailable response SHALL continue without privileged changes, while an approved installation SHALL use a provenance-checked signed package and SHALL fail before Homebrew if any required step fails.

#### Scenario: Nix is already available
- **WHEN** `nix` is executable on the inherited `PATH`
- **THEN** setup reports its version without prompting, downloading a package, invoking `sudo`, reinstalling Nix, migrating its distribution, or changing its configuration

#### Scenario: Missing Nix is explained before Homebrew
- **WHEN** `nix` is unavailable at the start of `macos.sh`
- **THEN** setup explains that Determinate Nix creates `/nix`, installs a daemon, and requires administrator authorization before prompting `Install Determinate Nix now? [y/N]` and before any Homebrew step

#### Scenario: User approves installation
- **WHEN** the user enters case-insensitive `y` or `yes`
- **THEN** setup begins the verified Determinate Nix installation

#### Scenario: User enters an invalid interactive response
- **WHEN** the response is neither an accepted yes value, an accepted no value, nor empty
- **THEN** setup rejects the response without installing and prompts again

#### Scenario: User declines installation
- **WHEN** the user enters case-insensitive `n` or `no`, submits an empty response, or standard input reaches end-of-file
- **THEN** setup performs no download or privileged installation, exits successfully, and allows Homebrew and notification setup to continue while Yazelix remains deferrable

#### Scenario: Determinate package is downloaded
- **WHEN** the user approves and Nix is missing
- **THEN** setup downloads `https://install.determinate.systems/determinate-pkg/stable/Universal` into a private temporary directory with HTTPS-only curl settings and does not pipe remote content into a shell

#### Scenario: Package provenance is accepted
- **WHEN** macOS package assessment reports Apple Developer Team ID `X3JQ4VPJZ6`
- **THEN** setup invokes the macOS system package installer through `sudo` and removes the staged package afterward

#### Scenario: Inherited environment attempts to replace Nix setup paths
- **WHEN** `macos.sh` inherits values that name an alternate Nix setup script, system command root, or daemon profile
- **THEN** production setup ignores those values and uses only its repository-owned helper plus the fixed macOS system and standard `/nix` paths

#### Scenario: Package provenance is missing or different
- **WHEN** package assessment fails, is unparsable, or reports any other Team ID
- **THEN** setup exits unsuccessfully before `sudo installer` or Homebrew executes and removes the staged package

#### Scenario: Approved installation completes
- **WHEN** the signed package installs successfully
- **THEN** setup activates the standard Nix daemon environment in the current bootstrap, verifies an executable Nix command, its version, and flake support, then continues to Homebrew

#### Scenario: Approved installation fails
- **WHEN** download, assessment, package installation, environment activation, version verification, or flakes verification fails after approval
- **THEN** `macos.sh` exits unsuccessfully before Homebrew, notification, or Yazelix setup

#### Scenario: Bootstrap is repeated after installation
- **WHEN** a later `macos.sh` run finds the installed `nix` command
- **THEN** Nix setup is prompt-free and performs no package installation

### Requirement: Yazelix setup is idempotent and deferrable
The macOS bootstrap SHALL attempt Yazelix setup after notification installation without the Yazelix step itself installing Nix or launching Yazelix. The setup SHALL converge through the stable Nova channel, SHALL retry one failed profile attempt once, and SHALL defer cleanly when Nix installation was declined and Nix remains unavailable.

#### Scenario: Yazelix is already installed
- **WHEN** `yzx` is already available on `PATH`
- **THEN** Yazelix setup exits successfully without invoking Nix

#### Scenario: Nix is available and Yazelix is absent
- **WHEN** `nix` is executable and `yzx` is unavailable
- **THEN** setup runs `nix profile add --refresh github:Yazelix/nova/stable`, reports success, and does not launch Yazelix

#### Scenario: Yazelix profile installation fails transiently
- **WHEN** the first Nix profile attempt fails and the second identical attempt succeeds
- **THEN** setup reports the bounded retry, reports success afterward, and invokes Nix exactly twice

#### Scenario: Yazelix profile installation keeps failing
- **WHEN** both Nix profile attempts fail
- **THEN** setup stops after the second attempt, returns that failure status, explains how to handle GitHub HTTP 429 output, and does not report success

#### Scenario: Nix download backoff is bounded
- **WHEN** a Yazelix profile attempt encounters a persistent download failure
- **THEN** each of the two profile invocations allows one Nix download attempt so internal HTTP retries do not multiply the bounded outer retry

#### Scenario: Bootstrap identifies adjacent installer output
- **WHEN** notification setup completes and Yazelix setup begins
- **THEN** the bootstrap prints each resolved installer path immediately before invoking it so subsequent Yazelix output is not attributed to the notification installer

#### Scenario: Nix is not installed
- **WHEN** the user declined the earlier Determinate Nix offer and `nix` remains unavailable on `PATH`
- **THEN** setup reports that Yazelix is deferred, exits successfully, and leaves the completed Homebrew and notification setup intact

#### Scenario: User completes new-Mac setup
- **WHEN** `macos.sh` and the separate generic `symlinks.sh` flow have completed
- **THEN** the documented explicit next command is `yzx launch`

### Requirement: Installation discovers account and tool paths
The installer and runtime scripts SHALL derive the home directory, Codex state directory, module siblings, JSON parser, Homebrew formula prefix, app destination, and Zellij executable without fixed user or architecture-specific paths.

#### Scenario: Apple Silicon user installs the module
- **WHEN** Homebrew resolves under its default Apple Silicon prefix
- **THEN** the installer uses the formula prefix returned by Homebrew and writes local generated paths for the active user

#### Scenario: A different supported Homebrew prefix is active
- **WHEN** `command -v brew` and `brew --prefix terminal-notifier` resolve under another supported prefix
- **THEN** installation and runtime discovery use those resolved locations without editing repository source

#### Scenario: CODEX_HOME is customized
- **WHEN** `CODEX_HOME` points outside `~/.codex`
- **THEN** the installer merges the config and hook files in that directory and renders the matching Sky path there

### Requirement: Runtime executables are installed as managed symlinks
The installer SHALL link the three repository-owned runtime scripts into `~/.local/bin`, preserve executable behavior, and replace only targets owned by this module after backing up conflicting files.

#### Scenario: Clean executable installation
- **WHEN** no existing runtime targets are present
- **THEN** `codex-notify`, `codex-permission-notify`, and `codex-notification-route` become executable symlinks to the module `bin` directory

#### Scenario: Standalone scripts already exist
- **WHEN** a runtime target is a regular file from the current installation
- **THEN** the installer backs it up and atomically replaces it with the intended repository symlink

#### Scenario: Symlinks are already current
- **WHEN** all runtime links already resolve to the intended source files
- **THEN** the installer leaves them unchanged and creates no needless backup

### Requirement: Terminal Notifier is reconstructed and verified
The installer SHALL copy the Homebrew Terminal Notifier app into a staged local bundle, apply ad-hoc signing, require strict deep signature verification, and activate it only after successful verification.

#### Scenario: App reconstruction succeeds
- **WHEN** the Homebrew formula contains the expected app bundle and signing succeeds
- **THEN** the verified bundle is atomically installed under `~/.local/share/codex-notify/terminal-notifier.app`

#### Scenario: Copy or signing fails
- **WHEN** staging, code signing, or strict verification fails
- **THEN** the previous active bundle remains intact, the failed staging path is cleaned up, and installation reports failure

### Requirement: Codex config merge is narrow and validated
The installer SHALL manage only top-level `notify` and `[tui].notifications`, preserve all unrelated TOML text, reject ambiguous owned values it cannot safely edit, and validate a candidate through Codex strict config loading before replacement.

#### Scenario: Existing config has unrelated state
- **WHEN** `config.toml` contains model preferences, projects, plugins, MCP servers, hook state, comments, or formatting
- **THEN** those contents remain unchanged while `notify` is converged to the Sky previous-notifier chain and `[tui].notifications` is set to false

#### Scenario: Existing owned setting is safely replaceable
- **WHEN** `notify` or `[tui].notifications` already has a supported one-line value
- **THEN** the installer replaces or inserts exactly one canonical value without duplicating its table

#### Scenario: Existing notify syntax is ambiguous
- **WHEN** the installer encounters a multiline or otherwise unsupported owned value
- **THEN** it aborts before replacing the real config and reports a manual remediation path

#### Scenario: Config contains an unrelated multiline string
- **WHEN** a line-oriented merge cannot safely distinguish key-like text inside a TOML multiline string
- **THEN** the installer rejects the unsupported config before mutation and preserves the original bytes

#### Scenario: Candidate config fails strict loading
- **WHEN** Codex doctor does not report `config.load` with status `ok` for the staged candidate
- **THEN** the original config remains active and the installer reports validation failure

### Requirement: Permission hook merge preserves other hooks
The installer SHALL use JSON-aware merging to install exactly one canonical notification-owned `PermissionRequest` group while retaining all unrelated hook events, matcher groups, and handlers.

#### Scenario: Hooks file contains unrelated handlers
- **WHEN** `hooks.json` already defines other permission or lifecycle hooks
- **THEN** those hooks remain semantically unchanged and one canonical `codex-permission-notify` handler is present

#### Scenario: Owned handler already exists
- **WHEN** one or more handlers target an earlier `codex-permission-notify` path
- **THEN** they are converged to exactly one canonical handler using the current installed path

#### Scenario: Hook definition changes
- **WHEN** installation changes the owned hook content or path
- **THEN** no trust hash is copied or synthesized and the installer tells the user to review the hook through `/hooks`

### Requirement: Installation protects previous state
Before replacing any existing script, app bundle, config, or hooks file, the installer SHALL save the prior target under the active XDG state backup root and use staged writes so a failed run does not leave partial active files.

#### Scenario: A run changes multiple targets
- **WHEN** installation will replace existing notification assets or settings
- **THEN** their prior versions are grouped under one timestamped `${XDG_STATE_HOME:-$HOME/.local/state}/cider/backups/codex-notify/` run directory

#### Scenario: A staged operation fails
- **WHEN** any staged target fails its required validation before activation
- **THEN** the corresponding previous active target remains unchanged or is restored from that run's backup

#### Scenario: User performs rollback
- **WHEN** the latest backup is selected for rollback
- **THEN** the previous scripts, app bundle, config, and hook files can be restored without requiring Git to contain generated state

#### Scenario: Managed state changed after installation
- **WHEN** any managed target no longer matches the selected run's recorded post-install fingerprint
- **THEN** rollback refuses the entire operation before changing any target and preserves the later state

### Requirement: Installer is idempotent and supports deferred activation
Repeated successful installation SHALL converge to the same filesystem and configuration state without duplicate hooks, duplicate settings, or unnecessary backups. Missing Codex or Sky prerequisites during general macOS bootstrap SHALL defer Codex activation without writing a broken notifier command.

#### Scenario: Installer runs twice
- **WHEN** no repository source, dependency, or local owned setting changes between two runs
- **THEN** the second run produces the same active state, no duplicate entries, and no new change backup

#### Scenario: Codex prerequisites are not ready during bootstrap
- **WHEN** `macos.sh` invokes the module before Codex or Sky Computer Use is available
- **THEN** the installer leaves Codex config and hooks untouched, reports deferred activation, prints the rerun command, and does not fail the unrelated Homebrew bootstrap

#### Scenario: Installer is rerun after prerequisites appear
- **WHEN** Codex and Sky become available after a deferred run
- **THEN** the same installer completes config and hook activation without requiring source edits

### Requirement: Portable installation and runtime behavior are verified
The repository SHALL provide automated tests that exercise the installer in isolated home directories and run the established notification behavior suite against portable module paths.

#### Scenario: Installer test suite runs
- **WHEN** tests use temporary `HOME`, `CODEX_HOME`, XDG state, Homebrew, app, signing, and command fixtures
- **THEN** clean install, migration, merge preservation, cross-user paths, idempotence, deferred activation, validation failure, and rollback behavior are asserted through observable outputs and files

#### Scenario: Runtime regression suite runs
- **WHEN** the module's notification tests execute after path refactoring
- **THEN** completion, permission, OSC bytes, content limits, sound, exact routing, and failure isolation retain their established behavior without requiring a live installation

#### Scenario: Live installation suite runs
- **WHEN** the module is installed for the current account
- **THEN** its three executable links target the module and the active Terminal Notifier helper passes strict deep signature verification

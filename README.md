# Cider dotfiles

## Installation

Run this:

```sh
git clone --recursive https://github.com/blesscat/dotfiles.git ~/.cider

cd ~/.cider
```

Run `./macos.sh` on macOS. It first offers to install Determinate Nix when Nix
is missing, installs the repository `Brewfile`, including the declared formulas
and five casks, then installs the portable Codex notification module and
attempts to install Yazelix through Nix. See
[codex-notify/README.md](codex-notify/README.md) for notification prerequisites,
deferred activation, verification, backups, and rollback.

The notification installer creates only its three documented runtime
symlinks. Other dotfile symlinks remain available through the repository's
existing generic workflow. Everything is configured and tweaked within
`~/.cider`.

Homebrew dependencies belong to `Brewfile`. The generic symlink metadata
remains in `bootstrap.json`; `macos.sh` does not automatically run the
symlink runner.

### Install Codex notifications separately

After the Homebrew dependencies are available, install only the Codex
notification integration with:

```sh
cd ~/.cider
./codex-notify/install.zsh
```

See the [Codex notification installation guide](codex-notify/README.md#prerequisites-and-installation)
for prerequisites, deferred activation, verification, backups, and rollback.

### New Mac setup flow

After cloning the repository on a new Mac, run:

```sh
cd ~/.cider
./macos.sh
./symlinks.sh
yzx launch
```

`macos.sh` performs the machine setup in this order:

1. Checks for Nix before Homebrew. Existing Nix is preserved. If Nix is
   missing, it explains that Determinate Nix creates `/nix`, installs a system
   daemon, and requires administrator authorization, then asks
   `Install Determinate Nix now? [y/N]`.
2. Installs or discovers Homebrew.
3. Applies Homebrew's `shellenv` when necessary.
4. Runs `brew bundle install --file=./Brewfile --no-upgrade`, installing the
   declared formulas and the DaisyDisk, Scroll Reverser, Warp, Ghostty, and
   Hammerspoon casks.
5. Runs `codex-notify/install.zsh`, which installs the notification runtime
   links and signed Terminal Notifier helper. Codex configuration and hooks
   are activated when Codex and Sky Computer Use are available; otherwise that
   part is deferred for a later installer run.
6. Runs `scripts/yazelix_setup.sh`. If `yzx` is already available, the step is
   a no-op. If Nix with flakes is available, it installs Yazelix with
   `nix profile add --refresh github:Yazelix/nova/stable`. A failed profile
   attempt is retried once for transient upstream build failures, with Nix's
   per-command download attempts bounded so a GitHub HTTP 429 does not trigger
   two long internal retry cycles. If GitHub rate-limits anonymous downloads,
   wait for the limit to reset or configure Nix `access-tokens`, then rerun
   `./scripts/yazelix_setup.sh`. If Nix is missing, Yazelix setup is deferred
   without failing the rest of the Mac bootstrap.

The Nix prompt defaults to No. Entering `n`, `no`, pressing Enter, or running
without interactive input skips Nix without failing Homebrew or notification
setup; Yazelix is deferred. Entering `y` or `yes` downloads Determinate's stable
Universal macOS package over HTTPS, requires Apple Developer Team ID
`X3JQ4VPJZ6`, and only then invokes the system installer through `sudo`.
Download, provenance, installation, environment, version, or flakes failures
after approval stop `macos.sh` before Homebrew begins.

To remove a Determinate Nix installation later, use its maintained uninstaller:

```sh
sudo /nix/nix-installer uninstall
```

`symlinks.sh` is a separate, opt-in step that applies the generic dotfile
symlink mappings from `bootstrap.json`. It is intentionally not invoked by
`macos.sh`, and the notification-specific links are managed by the notification
installer instead.

### Terminal background shortcuts

After the Fish configuration is linked, these commands change the background of
the current terminal surface without changing the terminal's saved theme:

```sh
bg-night
bg-ocean
bg-slate
bg-forest
bg-plum
bg-alert
bg-reset
```

The shared command lives at `scripts/terminal-bg` and is also exposed through
the Bash templates. Bash environments need a copy or mount of `~/.cider`; set
`CIDER_HOME` when the repository is available at a different path, such as an
OrbStack VM mount.

### Manage user-level agent skills

The maintained user-level skills are stored in `.agents/skills` and are activated
explicitly with:

```sh
cd ~/.cider
./scripts/agents_skills_setup.sh
```

The command links `~/.agents/skills` to the repository source while leaving
`~/.agents/.skill-lock.json` as local installation state. If an existing skill
directory or another link is found, it is moved to a timestamped
`~/.agents/skills.backup-*` path before activation. A failed activation restores
the previous path; to roll back a successful activation, remove the managed link
and move the selected backup back to `~/.agents/skills`.

This migration is intentionally not run by `macos.sh` or the generic
`symlinks.sh` runner.

Yazelix is not launched automatically because its first launch is interactive
and may update editor configuration. After applying the repository symlinks,
run `yzx launch` when you are ready. If installation was deferred, install Nix
with flakes enabled, rerun `./scripts/yazelix_setup.sh`, and then run
`yzx launch`.

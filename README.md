# Cider dotfiles

## Installation

Run this:

```sh
git clone --recursive https://github.com/blesscat/dotfiles.git ~/.cider

cd ~/.cider
```

Run `./macos.sh` on macOS. It installs the repository `Brewfile`, including the
declared formulas and four casks, then installs the portable Codex notification
module. See
[codex-notify/README.md](codex-notify/README.md) for notification prerequisites,
deferred activation, verification, backups, and rollback.

The notification installer creates only its two documented runtime
symlinks. Other dotfile symlinks remain available through the repository's
existing generic workflow. Everything is configured and tweaked within
`~/.cider`.

### Optional Lima Docker environment

Cider can provision Lima as an opt-in Docker Engine environment without
starting or modifying OrbStack. The checked-in Lima configurations require
Lima 2.2.0 or newer. For first-time setup, initialize the normal development
VM, Docker context, and macOS login autostart registration in one command:

```sh
cd ~/.cider
./lima_init.sh
```

`lima_init.sh` is safe to run again: it installs any missing host prerequisites,
starts the existing `dev` VM when needed, refreshes the `lima-dev` Docker
context, and keeps autostart enabled.

The `dev` VM mounts only macOS `~/.cider`, using Lima's default guest mount
location `/Users/blesscat/.cider`. Guest `~/.cider` is a symlink to that mount.
Guest `~/doc` and `~/.codex` are real directories on the Linux VM disk, so
project dependencies, Codex releases, sessions, sockets, and other
platform-specific state are never shared with macOS. The configuration does
not override `CODEX_HOME`; Codex therefore uses the guest's normal
`~/.codex`.

Lima forwards the macOS SSH agent into the trusted `dev` VM, so guest-native
repositories can use GitHub without copying another host private key into the
VM. Ensure the required key is loaded on macOS, then verify it from the guest:

```sh
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
limactl shell dev -- ssh-add -l
```

The VM's SSH endpoint is fixed at `127.0.0.1:62180`. Lima dynamically forwards
guest localhost service ports to the same macOS localhost port, so common
development and Supabase ports work without listing each one here. Project
repositories continue to own their Compose definitions.

For a `dev` VM created with the older shared `~/doc` and `~/.codex` layout,
back up important Docker volumes and run the one-time in-place migration:

```sh
cd ~/.cider
./scripts/lima_guest_native_migrate.sh
```

The migration backs up the live Lima configuration, preserves the VM disk and
Docker volumes, keeps only the Cider mount, creates the guest-local directories,
installs Linux Codex into guest `~/.codex`, and refreshes the macOS
`lima-dev` Docker context. It does not copy macOS projects into the VM; clone or
copy only the projects and local environment files that the Linux workspace
needs.

Update the Linux Codex runtime and restart its app-server daemon in one command:

```sh
cd ~/.cider
./scripts/lima_codex_update.sh
```

The updater starts `dev` when needed, runs the official Codex installer inside
Lima with `CODEX_HOME` unset, and bootstraps Codex's built-in remote-control
daemon. Linux releases and daemon state remain under the guest's `~/.codex`,
while the macOS Codex runtime remains unchanged. The remote connection can
disconnect briefly while the daemon restarts.

Select the named context before using Docker:

```sh
docker context use lima-dev
docker info
```

The macOS Docker CLI can inspect images, containers, networks, and volumes
through this context. Commands that resolve project bind mounts must run from
the guest-native checkout, because the Docker daemon interprets source paths in
the Lima filesystem:

```sh
limactl shell --workdir /home/blesscat.guest/doc/autoIQ dev -- mise run db:start
```

Do not run a project Compose or Supabase command from the macOS copy of the
repository and pass its macOS path to the Lima Docker daemon. Docker named
volumes, including database data, stay on the Lima virtual disk; do not
bind-mount a macOS directory as a live database data directory. Manage the VM
explicitly:

```sh
./scripts/lima_lifecycle.sh status dev
./scripts/lima_lifecycle.sh stop dev
./scripts/lima_lifecycle.sh start dev
./scripts/lima_lifecycle.sh autostart dev
```

`lima_lifecycle.sh` accepts an action and an optional instance name
(`dev` or `agent`). If both are omitted, it shows the status of `dev`:

- `start`: creates the VM from its repository configuration when missing, or starts the existing VM.
- `stop`: stops the selected VM without deleting it or its data.
- `status`: shows the selected VM status.
- `autostart`: registers the selected VM to start automatically when the macOS user logs in.
- `destroy`: asks for the exact instance name, then deletes the VM and its guest-side Docker volumes.

Use `destroy` only after backing up any important Docker volumes. It does not
modify macOS files or OrbStack.

Remove the login registration with `limactl autostart disable dev`. The
selected VM must already exist before enabling autostart.

Destroying a VM deletes its guest-side Docker volumes. Stop the service first,
then back up an important volume with the Lima Docker context selected:

```sh
limactl shell dev -- sh -lc '
  backup="$HOME/lima-volume-backups"
  install -d -m 0700 "$backup"
  source="$(docker volume inspect supabase_db_autoIQ --format "{{.Mountpoint}}")"
  sudo tar --numeric-owner -czf "$backup/supabase_db_autoIQ.tgz" -C "$source" .
  sudo chown "$USER":"$(id -gn)" "$backup/supabase_db_autoIQ.tgz"
'
limactl copy dev:/home/blesscat.guest/lima-volume-backups/supabase_db_autoIQ.tgz ./
```

Restore into an existing empty volume with:

```sh
limactl copy ./supabase_db_autoIQ.tgz dev:/home/blesscat.guest/lima-volume-backups/
limactl shell dev -- sh -lc '
  source="$(docker volume inspect supabase_db_autoIQ --format "{{.Mountpoint}}")"
  sudo tar --numeric-owner -xzf "$HOME/lima-volume-backups/supabase_db_autoIQ.tgz" -C "$source"
'
```

Only after verifying the backup, explicitly run
`./scripts/lima_lifecycle.sh destroy dev` and type `dev` when prompted. Create
the VM again with `./scripts/lima_lifecycle.sh start dev`; project Compose
commands then recreate the named volumes and services.

For an isolated AI-agent workflow, create the mount-free VM:

```sh
./scripts/lima_create.sh agent
cd ~/doc/autoIQ
limactl shell --sync "$PWD" agent -- codex
```

`--sync` copies the project into the guest and asks before syncing changes back
to macOS. It is not continuous synchronization, and it cannot be used with a
VM that has host mounts. Keep the sync directory limited to a project rather
than a home directory or large dependency/build tree.

The Lima VM is separate from OrbStack. During migration, keep OrbStack
available and switch Docker contexts explicitly; this repository does not
migrate, delete, or overwrite OrbStack data.

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
```

`macos.sh` performs the machine setup in this order:

1. Installs or discovers Homebrew.
2. Applies Homebrew's `shellenv` when necessary.
3. Runs `brew bundle install --file=./Brewfile --no-upgrade`, installing the
   declared formulas and the DaisyDisk, Scroll Reverser, Warp, and Ghostty
   casks.
4. Runs `codex-notify/install.zsh`, which installs the notification runtime
   links and signed Terminal Notifier helper. Codex configuration and hooks
   are activated when Codex and Sky Computer Use are available; otherwise that
   part is deferred for a later installer run.

`symlinks.sh` is a separate, opt-in step that applies the generic dotfile
symlink mappings from `bootstrap.json`. It is intentionally not invoked by
`macos.sh`, and the notification-specific links are managed by the notification
installer instead.

### New Omarchy setup flow

On an [Omarchy](https://omarchy.org/) machine (Arch Linux + Hyprland), clone the
repository and run:

```sh
cd ~/.cider
./omarchy.sh
```

`omarchy.sh` does not use `bootstrap.json` or `symlinks.sh`; its package and
link lists are arrays at the top of the script. It runs these steps, and is
safe to rerun:

1. Installs the listed packages with `omarchy pkg add` and the AUR packages
   (`rime-ice-git`, `blesh-git`, `zen-browser-bin`) with `omarchy pkg aur add`.
   This prompts for the sudo password. Pass `--skip-packages` to skip this
   step.
2. Links the Linux-safe dotfiles: Git config and global ignore,
   `.editorconfig`, ble.sh's `.blerc`, the Claude Code status line script and
   commands, Helix `config.toml` and `languages.toml`, lazygit, and the tracked
   Herdr customizations (see below). It also links `~/.local/bin/hx` to `/usr/bin/helix`, because Arch ships Helix as `helix`,
   and links `~/.config/helix/themes/mytheme.toml` to the active Omarchy theme
   so the shared Helix config follows Omarchy theme switches.
3. Sets `statusLine` in `~/.claude/settings.json`, and adds two marked
   blocks to Omarchy's `~/.bashrc` that load ble.sh (fish-like
   autosuggestions, syntax highlighting, and completion menu) and
   `shell/omarchy.bash`, where personal aliases such as `lg` live. The rest
   of Omarchy's `.bashrc` is left alone.
4. Runs `scripts/rime_setup.sh`, then makes Fcitx5 use `keyboard-us` + Rime.
   Left Shift is removed from Fcitx5's switch keys so Rime receives it, and
   the candidate list is vertical.

An existing file at a link destination is moved to
`<name>.pre-cider.<timestamp>` first. Links that already point at the
repository are left alone.

Input method use on Omarchy:

- `Super+I` switches between the English keyboard and Rime. After a reboot,
  Fcitx5 starts on the English keyboard, so press it once.
- Inside Rime, Left Shift toggles Chinese and English. Bopomofo starts in
  English, the same as on macOS.
- `` Ctrl+` `` or `F4` switches between Bopomofo and Rime Ice Pinyin.

In a UTM VM on Apple silicon, `herdr-app` aborts inside the Venus Vulkan
driver (`vulkan-virtio`). Install `vulkan-swrast` and start it on the CPU
driver instead, for example with a `~/.local/share/applications/herdr-app.desktop`
override whose `Exec` is
`env VK_DRIVER_FILES=/usr/share/vulkan/icd.d/lvp_icd.json herdr-app`. This is
machine-specific, so `omarchy.sh` does not do it.

Shell startup files, terminal configs, and Neovim are not linked, because
Omarchy manages its own `.bashrc`, themed terminal configs, and LazyVim setup.

### Terminal background shortcuts

After the zsh configuration (`symlinks/zsh/.zshrc`) is linked, these commands change the background of
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
the zsh and Bash templates. Bash environments need a copy or mount of `~/.cider`; set
`CIDER_HOME` when the repository is available at a different path, such as an
OrbStack VM mount.

### Herdr customizations

The repository tracks only the Herdr files that were customized. Herdr still
owns the rest of `~/.config/herdr-app`, including the shipped mods, layouts,
icons, `keys.json` and `settings.json`. The tracked files are linked through
`bootstrap.json`:

- `mods/usage-limits/`: the bottom usage bar. It is adapted from
  nozikov/herdr-usage-limits under the MIT license, and shows remaining quota.
- `layouts/main-usage-limits.json`: the layout that mounts the usage bar.
- `programs.json` and `my-icons/`: custom program names and icons, such as
  MiniMax for `mcode`.

Herdr writes `gpui-kit.d.ts` and `jsconfig.json` into each mod folder. They are
ignored here.

Herdr's hot reload does not follow symlinks, so editing a tracked mod here does
not reload it. Run this after editing:

```sh
~/.cider/scripts/herdr_reload_mods.sh
```

The Claude Code status line script is tracked at
`symlinks/.claude/statusline.sh`. `~/.claude/settings.json` is not tracked, so
on a new machine, point its `statusLine` command at that script:

```json
"statusLine": { "type": "command", "command": "bash \"$HOME/.claude/statusline.sh\"" }
```

### Agent usage page

`agent-usage/` is a small page that shows the remaining quota of Claude Code,
Codex, ZCode, MiniMax and Antigravity, for checking from a phone over
Tailscale. It runs as a systemd user service on Linux and a launchd agent on
macOS:

```sh
~/.cider/agent-usage/install.sh
```

See [agent-usage/README.md](agent-usage/README.md) for settings, HTTPS for
installing it as an app, and where each number comes from.

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

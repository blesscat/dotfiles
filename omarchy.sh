#!/usr/bin/env bash
# Omarchy (Arch Linux + Hyprland) bootstrap for cider.
#
# 1. Installs the packages listed below (official repos + AUR).
# 2. Links the Linux-safe dotfiles from symlinks/ into $HOME. An existing file
#    is moved aside to <name>.pre-cider.<timestamp> first; links that already
#    point at the repo are left alone, so the script is safe to rerun.
# 3. Points Claude Code's statusLine at the linked script.
# 4. Sets up Rime (Bopomofo + Rime Ice Pinyin) through scripts/rime_setup.sh
#    and makes it the active Fcitx5 input method.
#
# Usage: ./omarchy.sh [--skip-packages]

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir
readonly stamp="$(date +%Y%m%d-%H%M%S)"

# Official-repo packages.
readonly -a packages=(
  helix
  lazygit
  fcitx5-rime
  rime-bopomofo
  rime-terra-pinyin
)

# AUR packages.
readonly -a aur_packages=(
  rime-ice-git
)

# "<path under symlinks/>|<destination>"
readonly -a links=(
  "git/.gitconfig|$HOME/.gitconfig"
  ".config/git/ignore|$HOME/.config/git/ignore"
  "editorconfig/.editorconfig|$HOME/.editorconfig"
  ".claude/statusline.sh|$HOME/.claude/statusline.sh"
  "claude/commands|$HOME/.claude/commands"
  ".config/helix/config.toml|$HOME/.config/helix/config.toml"
  ".config/helix/languages.toml|$HOME/.config/helix/languages.toml"
  ".config/lazygit/config.yml|$HOME/.config/lazygit/config.yml"
)

# Links to things outside the repo: "<absolute source>|<destination>"
readonly -a system_links=(
  # Arch ships Helix as `helix`; lazygit, yazi and EDITOR call `hx`.
  "/usr/bin/helix|$HOME/.local/bin/hx"
  # The shared Helix config uses theme "mytheme"; on Omarchy resolve it to the
  # active Omarchy theme so Helix follows theme switches.
  "$HOME/.local/state/omarchy/current/theme/helix.toml|$HOME/.config/helix/themes/mytheme.toml"
)

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

skip_packages=0
for arg in "$@"; do
  case "$arg" in
    --skip-packages) skip_packages=1 ;;
    -h | --help)
      sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown option: $arg" ;;
  esac
done

command -v omarchy >/dev/null 2>&1 || die 'omarchy command not found; this script targets Omarchy.'
command -v jq >/dev/null 2>&1 || die 'jq is required.'

install_packages() {
  if (( skip_packages )); then
    log 'Skipping package installation (--skip-packages)'
    return
  fi
  log "Installing packages: ${packages[*]}"
  omarchy pkg add "${packages[@]}"
  log "Installing AUR packages: ${aur_packages[*]}"
  omarchy pkg aur add "${aur_packages[@]}"
}

link_one() {
  local source="$1"
  local destination="$2"

  if [[ ! -e "$source" ]]; then
    warn "source missing, skipped: $source"
    return
  fi

  if [[ -L "$destination" && "$(readlink "$destination")" == "$source" ]]; then
    printf '  ok      %s\n' "$destination"
    return
  fi

  mkdir -p "$(dirname "$destination")"
  if [[ -e "$destination" || -L "$destination" ]]; then
    local backup="$destination.pre-cider.$stamp"
    mv "$destination" "$backup"
    printf '  backup  %s -> %s\n' "$destination" "$backup"
  fi

  ln -s "$source" "$destination"
  printf '  linked  %s -> %s\n' "$destination" "$source"
}

link_dotfiles() {
  log 'Linking dotfiles'
  local entry
  for entry in "${links[@]}"; do
    link_one "$script_dir/symlinks/${entry%%|*}" "${entry#*|}"
  done
  for entry in "${system_links[@]}"; do
    link_one "${entry%%|*}" "${entry#*|}"
  done
}

configure_claude_statusline() {
  local settings="$HOME/.claude/settings.json"
  local command='bash "$HOME/.claude/statusline.sh"'
  local current tmp

  log 'Configuring Claude Code statusLine'
  mkdir -p "$(dirname "$settings")"
  [[ -s "$settings" ]] || printf '{}\n' > "$settings"

  current="$(jq -r '.statusLine.command // empty' "$settings")"
  if [[ "$current" == "$command" ]]; then
    printf '  ok      %s\n' "$settings"
    return
  fi

  tmp="$(mktemp)"
  jq --arg cmd "$command" '.statusLine = {type: "command", command: $cmd}' \
    "$settings" > "$tmp"
  cp "$settings" "$settings.pre-cider.$stamp"
  mv "$tmp" "$settings"
  printf '  updated %s\n' "$settings"
}

restart_fcitx5() {
  if systemctl --user cat omarchy-fcitx5.service >/dev/null 2>&1; then
    systemctl --user start omarchy-fcitx5.service
  else
    (setsid fcitx5 -d --replace >/dev/null 2>&1 &)
  fi
}

configure_fcitx5() {
  local profile="$HOME/.config/fcitx5/profile"
  local attempt

  log 'Setting Fcitx5 input methods: keyboard-us + rime'

  # Fcitx5 rewrites its profile on exit, so stop it before editing.
  systemctl --user stop omarchy-fcitx5.service >/dev/null 2>&1 || true
  pkill -u "$UID" -x fcitx5 >/dev/null 2>&1 || true
  for attempt in {1..50}; do
    pgrep -u "$UID" -x fcitx5 >/dev/null || break
    sleep 0.1
  done

  mkdir -p "$(dirname "$profile")"
  if [[ -f "$profile" ]]; then
    cp "$profile" "$profile.pre-cider.$stamp"
  fi
  cat > "$profile" <<'EOF'
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=rime

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
# Layout=

[Groups/0/Items/1]
# Name
Name=rime
# Layout
# Layout=

[GroupOrder]
0=Default
EOF

  # Let Rime receive Left Shift for its own Chinese/English toggle (as on
  # macOS Squirrel). Fcitx5's AltTriggerKeys would otherwise swallow it and
  # only flip between keyboard-us and Rime. Super+I switches input methods.
  local config="$HOME/.config/fcitx5/config"
  if [[ -f "$config" ]]; then
    cp "$config" "$config.pre-cider.$stamp"
    sed -i '/^\[Hotkey\/AltTriggerKeys\]/,/^$/{/^[0-9]\+=/d}' "$config"
  fi

  # Show candidates as a vertical list.
  local classicui="$HOME/.config/fcitx5/conf/classicui.conf"
  mkdir -p "$(dirname "$classicui")"
  touch "$classicui"
  if grep -q '^Vertical Candidate List=' "$classicui"; then
    sed -i 's/^Vertical Candidate List=.*/Vertical Candidate List=True/' "$classicui"
  else
    printf 'Vertical Candidate List=True\n' >> "$classicui"
  fi

  restart_fcitx5
}

setup_rime() {
  log 'Setting up Rime (Bopomofo + Rime Ice)'
  bash "$script_dir/scripts/rime_setup.sh"
  configure_fcitx5
}

install_packages
link_dotfiles
configure_claude_statusline
setup_rime

log 'Done.'
cat <<'EOF'
Rime: Super+I switches between keyboard-us and Rime.
      Inside Rime, Left Shift toggles Chinese/English (starts in English).
      Ctrl+` (or F4) switches Bopomofo (bopomofo_tw) / Rime Ice Pinyin (rime_ice).
EOF

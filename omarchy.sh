#!/usr/bin/env bash
# Omarchy (Arch Linux + Hyprland) bootstrap for cider.
#
# 1. Installs the packages listed below (official repos + AUR).
# 2. Links the Linux-safe dotfiles from symlinks/ into $HOME. An existing file
#    is moved aside to <name>.pre-cider.<timestamp> first; links that already
#    point at the repo are left alone, so the script is safe to rerun.
# 3. Points Claude Code's statusLine at the linked script.
# 4. Installs the Tridactyl native messenger so Zen's Tridactyl loads the
#    linked tridactylrc, and hc-tui (herdr-core TUI) into ~/.local/bin.
# 5. Sets Zen's space-switching shortcuts to Alt+Shift+Left/Right from
#    zen/customKeys.json (Zen must be closed).
# 6. Writes the agents panel's Z.ai and MiniMax keys from the GNOME keyring
#    through scripts/agent_usage_keys.sh.
# 7. Sets up Rime (Bopomofo + Rime Ice Pinyin) through scripts/rime_setup.sh
#    and makes it the active Fcitx5 input method.
# 8. In a UTM VM (QEMU with a SPICE channel), runs omarchy-utm.sh for the
#    VM-only fixes and Mac<->VM clipboard sharing.
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
  herdr-app
)

# AUR packages.
readonly -a aur_packages=(
  rime-ice-git
  blesh-git
  zen-browser-bin
)

# "<path under symlinks/>|<destination>"
readonly -a links=(
  "git/.gitconfig|$HOME/.gitconfig"
  ".config/git/ignore|$HOME/.config/git/ignore"
  "editorconfig/.editorconfig|$HOME/.editorconfig"
  "blesh/.blerc|$HOME/.blerc"
  ".claude/statusline.sh|$HOME/.claude/statusline.sh"
  "claude/commands|$HOME/.claude/commands"
  ".config/helix/config.toml|$HOME/.config/helix/config.toml"
  ".config/helix/languages.toml|$HOME/.config/helix/languages.toml"
  ".config/lazygit/config.yml|$HOME/.config/lazygit/config.yml"
  # Herdr keys, also read by hc-tui (Ctrl+1..9 switches spaces).
  ".config/herdr/config.toml|$HOME/.config/herdr/config.toml"
  ".config/herdr-app/mods/usage-limits|$HOME/.config/herdr-app/mods/usage-limits"
  ".config/herdr-app/my-icons|$HOME/.config/herdr-app/my-icons"
  ".config/herdr-app/programs.json|$HOME/.config/herdr-app/programs.json"
  ".config/herdr-app/layouts/main-usage-limits.json|$HOME/.config/herdr-app/layouts/main-usage-limits.json"
  ".config/tridactyl/tridactylrc|$HOME/.config/tridactyl/tridactylrc"
  # Overrides Omarchy's template: tighter Fcitx5 candidate rows.
  ".config/omarchy/themed/fcitx5-theme.conf.tpl|$HOME/.config/omarchy/themed/fcitx5-theme.conf.tpl"
  # Personal Hyprland bindings (Alt+Shift+H/L switch Zen spaces).
  ".config/hypr/bindings.lua|$HOME/.config/hypr/bindings.lua"
  # Chromium with a local CDP port so Claude Code can drive the browser.
  ".local/bin/chromium-cdp|$HOME/.local/bin/chromium-cdp"
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
      sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

configure_bash() {
  local bashrc="$HOME/.bashrc"
  local blesh=/usr/share/blesh/ble.sh

  log 'Enabling ble.sh in ~/.bashrc'
  if [[ ! -r "$blesh" ]]; then
    warn "ble.sh not installed ($blesh); skipped"
    return
  fi
  if [[ ! -f "$bashrc" ]]; then
    warn "$bashrc not found; skipped"
    return
  fi
  if grep -q '# >>> cider ble.sh >>>' "$bashrc"; then
    printf '  ok      %s\n' "$bashrc"
    return
  fi

  cp "$bashrc" "$bashrc.pre-cider.$stamp"
  # ble.sh must be sourced early with --noattach (after Omarchy's
  # non-interactive early return) and attached at the very end.
  awk -v blesh="$blesh" '
    { print }
    !done && /^\[\[ \$- != \*i\* \]\] && return/ {
      print ""
      print "# >>> cider ble.sh >>>"
      print "[[ -r " blesh " ]] && source " blesh " --noattach"
      print "# <<< cider ble.sh <<<"
      done = 1
    }
    END {
      if (!done) exit 1
      print ""
      print "# >>> cider ble-attach >>>"
      print "[[ ! ${BLE_VERSION-} ]] || ble-attach"
      print "# <<< cider ble-attach <<<"
    }
  ' "$bashrc" > "$bashrc.cider-tmp" || {
    rm -f "$bashrc.cider-tmp"
    warn "could not find the interactive-shell guard in $bashrc; skipped"
    return
  }
  mv "$bashrc.cider-tmp" "$bashrc"
  printf '  updated %s\n' "$bashrc"
}

configure_bash_extras() {
  local bashrc="$HOME/.bashrc"
  local extras="$script_dir/shell/omarchy.bash"

  log 'Loading cider shell additions from ~/.bashrc'
  if [[ ! -f "$bashrc" ]]; then
    warn "$bashrc not found; skipped"
    return
  fi
  if grep -q '# >>> cider shell >>>' "$bashrc"; then
    printf '  ok      %s\n' "$bashrc"
    return
  fi

  cp "$bashrc" "$bashrc.pre-cider.$stamp"
  # Insert before ble-attach when present, since ble-attach must stay last.
  awk -v extras="$extras" '
    function block() {
      print "# >>> cider shell >>>"
      print "[[ -r \"" extras "\" ]] && source \"" extras "\""
      print "# <<< cider shell <<<"
      print ""
      done = 1
    }
    !done && /^# >>> cider ble-attach >>>/ { block() }
    { print }
    END { if (!done) { print ""; block() } }
  ' "$bashrc" > "$bashrc.cider-tmp"
  mv "$bashrc.cider-tmp" "$bashrc"
  printf '  updated %s\n' "$bashrc"
}

# Tridactyl only reads tridactylrc through its native messenger, which is not
# packaged in the official repos. Use Tridactyl's own installer; it puts
# native_main in ~/.local/share/tridactyl and the manifest in
# ~/.mozilla/native-messaging-hosts, which Zen also reads.
install_tridactyl_native() {
  local data="${XDG_DATA_HOME:-$HOME/.local/share}/tridactyl/native_main"
  local manifest="$HOME/.mozilla/native-messaging-hosts/tridactyl.json"
  local url=https://raw.githubusercontent.com/tridactyl/native_messenger/master/installers/install.sh
  local tmp

  log 'Installing the Tridactyl native messenger'
  if [[ -x "$data" && -f "$manifest" ]]; then
    printf '  ok      %s\n' "$data"
    return
  fi
  if (( skip_packages )); then
    warn 'not installed; skipped (--skip-packages)'
    return
  fi

  tmp="$(mktemp)"
  if curl -fsSL "$url" -o "$tmp" && sh "$tmp"; then
    printf '  installed %s\n' "$data"
  else
    warn 'Tridactyl native messenger install failed; tridactylrc will not load'
  fi
  rm -f "$tmp"
}

# hc-tui (github.com/followcat/hc-tui), the herdr-core TUI that
# Super+Ctrl+Return opens, ships no package. Fetch its latest release into
# ~/.local/bin after checking sha256sums.txt; once there, `hc-tui --upgrade`
# keeps it current, so an existing binary is left alone.
install_hc_tui() {
  local bin="$HOME/.local/bin/hc-tui"
  local repo=https://github.com/followcat/hc-tui
  local arch tag tarball tmp

  log 'Installing hc-tui'
  if [[ -x "$bin" ]]; then
    printf '  ok      %s\n' "$bin"
    return
  fi
  if (( skip_packages )); then
    warn 'not installed; skipped (--skip-packages)'
    return
  fi

  arch="$(uname -m)"
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$repo/releases/latest")" || tag=
  tag="${tag##*/}"
  if [[ "$tag" != v* ]]; then
    warn 'could not find the latest hc-tui release; Super+Ctrl+Return will not work'
    return
  fi
  tarball="hc-tui-${tag#v}-${arch}-unknown-linux-musl.tar.gz"

  tmp="$(mktemp -d)"
  if curl -fsSL "$repo/releases/download/$tag/$tarball" -o "$tmp/$tarball" &&
     curl -fsSL "$repo/releases/download/$tag/sha256sums.txt" -o "$tmp/sha256sums.txt" &&
     (cd "$tmp" && grep -E " \*?$tarball\$" sha256sums.txt | sha256sum -c --status -) &&
     tar -xzf "$tmp/$tarball" -C "$tmp" &&
     install -Dm755 "$tmp/hc-tui" "$bin"; then
    printf '  installed %s (%s)\n' "$bin" "$tag"
  else
    warn 'hc-tui install failed; Super+Ctrl+Return will not work'
  fi
  rm -rf "$tmp"
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

  # Show candidates as a vertical list, in a larger font than the default
  # Sans 10. Omarchy's theme switcher leaves these keys alone.
  local classicui="$HOME/.config/fcitx5/conf/classicui.conf"
  mkdir -p "$(dirname "$classicui")"
  touch "$classicui"
  set_ini_key "$classicui" 'Vertical Candidate List' 'True'
  set_ini_key "$classicui" 'Font' '"Sans 14"'
  set_ini_key "$classicui" 'MenuFont' '"Sans 13"'

  # Regenerate the theme so the linked fcitx5-theme.conf.tpl override applies.
  omarchy-theme-refresh >/dev/null 2>&1 || warn 'omarchy-theme-refresh failed; Fcitx5 spacing applies after the next theme switch'

  restart_fcitx5
}

# Set key=value in a section-less ini file, replacing an existing entry.
set_ini_key() {
  local file="$1" key="$2" value="$3"
  if grep -q "^$key=" "$file"; then
    sed -i "s|^$key=.*|$key=$value|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

# Merge zen/customKeys.json into every Zen profile's customKeys.json (Firefox's
# about:keyboard store). Space switching moves off Ctrl+Alt+Left/Right, which
# UTM uses to release input capture. Zen reads the file only at startup and
# rewrites it from memory when a shortcut changes, so Zen must be closed.
configure_zen() {
  local keys="$script_dir/zen/customKeys.json"
  local zen_dir profiles_ini path profile target tmp found=0

  log 'Setting Zen keyboard shortcuts'
  if pgrep -u "$UID" -x zen-bin >/dev/null; then
    warn 'Zen is running; close it and rerun to apply the shortcuts'
    return
  fi

  for zen_dir in "$HOME/.config/zen" "$HOME/.zen"; do
    profiles_ini="$zen_dir/profiles.ini"
    [[ -f "$profiles_ini" ]] || continue
    while IFS= read -r path; do
      if [[ "$path" == /* ]]; then
        profile="$path"
      else
        profile="$zen_dir/$path"
      fi
      [[ -d "$profile" ]] || continue
      found=1
      target="$profile/customKeys.json"
      tmp="$(mktemp)"
      if [[ -f "$target" ]]; then
        jq -s '.[0] * .[1]' "$target" "$keys" > "$tmp"
      else
        jq . "$keys" > "$tmp"
      fi
      if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
        rm -f "$tmp"
        printf '  ok      %s\n' "$target"
      else
        mv "$tmp" "$target"
        printf '  updated %s\n' "$target"
      fi
    done < <(sed -n 's/^Path=//p' "$profiles_ini")
  done

  (( found )) || warn 'no Zen profile yet; start Zen once, close it, and rerun'
}

# Z.ai and MiniMax keys for the Omarchy agents panel live in the GNOME keyring;
# write the files its collectors read. A key not stored yet is only reported.
apply_agent_usage_keys() {
  log 'Writing agent usage keys from the keyring'
  bash "$script_dir/scripts/agent_usage_keys.sh" apply ||
    warn 'could not read the keyring; run scripts/agent_usage_keys.sh later'
}

setup_rime() {
  log 'Setting up Rime (Bopomofo + Rime Ice)'
  bash "$script_dir/scripts/rime_setup.sh"
  configure_fcitx5
}

# In a UTM VM (QEMU with UTM's SPICE agent channel), also run omarchy-utm.sh.
run_utm_setup() {
  [[ "$(systemd-detect-virt 2>/dev/null)" == qemu && -e /dev/virtio-ports/com.redhat.spice.0 ]] || return 0
  log 'UTM VM detected; running omarchy-utm.sh'
  local -a args=()
  (( skip_packages )) && args+=(--skip-packages)
  bash "$script_dir/omarchy-utm.sh" "${args[@]}"
}

install_packages
link_dotfiles
configure_claude_statusline
configure_bash
configure_bash_extras
install_tridactyl_native
install_hc_tui
configure_zen
apply_agent_usage_keys
setup_rime
run_utm_setup

log 'Done.'
cat <<'EOF'
Rime: Super+I switches between keyboard-us and Rime.
      Inside Rime, Left Shift toggles Chinese/English (starts in English).
      Ctrl+` (or F4) switches Bopomofo (bopomofo_tw) / Rime Ice Pinyin (rime_ice).
EOF

#!/usr/bin/env bash
# UTM-only Omarchy setup for cider, for an Omarchy VM in UTM on Apple silicon.
# omarchy.sh runs this automatically when it detects UTM; it can also be run
# on its own.
#
# 1. Starts LocalSend with software GL and herdr-app with lavapipe through
#    launcher overrides in ~/.local/share/applications. virgl's GPU drivers
#    break both (LocalSend shows a black window, herdr-app aborts).
# 2. Builds omarchy-spice-guest-tools for Mac<->VM clipboard sharing and
#    display resizing, and starts its display bridge before spice-vdagent so
#    the window size UTM sends at login is not missed.
# 3. Watches ~/.config/hypr/monitors.lua and removes the per-output rules
#    Omarchy's display scaling writes, which would undo display resizing.
#
# Usage: ./omarchy-utm.sh [--skip-packages]

set -euo pipefail

readonly stamp="$(date +%Y%m%d-%H%M%S)"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

skip_packages=0
for arg in "$@"; do
  case "$arg" in
    --skip-packages) skip_packages=1 ;;
    -h | --help)
      sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown option: $arg" ;;
  esac
done

# True in a UTM VM: QEMU with UTM's SPICE agent channel.
is_utm_vm() {
  [[ "$(systemd-detect-virt 2>/dev/null)" == qemu && -e /dev/virtio-ports/com.redhat.spice.0 ]]
}

# Copy an app's system launcher to ~/.local/share/applications with
# "env <vars>" prepended to its Exec lines, so the app menu starts it that way.
override_launcher_env() {
  local name="$1" vars="$2"
  local system_entry="/usr/share/applications/$name.desktop"
  local entry="$HOME/.local/share/applications/$name.desktop"
  local tmp

  if [[ ! -f "$system_entry" ]]; then
    warn "$name is not installed; skipped"
    return
  fi

  tmp="$(mktemp)"
  awk -v prefix="env $vars " '
    /^Exec=/ {
      command = substr($0, 6)
      if (index(command, prefix) == 1) command = substr(command, length(prefix) + 1)
      print "Exec=" prefix command
      next
    }
    { print }
  ' "$system_entry" > "$tmp"
  if [[ -f "$entry" ]] && cmp -s "$tmp" "$entry"; then
    rm -f "$tmp"
    printf '  ok      %s\n' "$entry"
    return
  fi
  mkdir -p "$(dirname "$entry")"
  [[ -f "$entry" ]] && cp "$entry" "$entry.pre-cider.$stamp"
  mv "$tmp" "$entry"
  chmod 644 "$entry"
  printf '  updated %s\n' "$entry"
}

# virgl's GPU drivers break two apps, so their launchers fall back to the CPU:
# - LocalSend (Flutter/GTK3) cannot create an OpenGL context and shows a black
#   window; use Mesa's software GL.
# - herdr-app aborts inside the Venus Vulkan driver (vulkan-virtio); use
#   lavapipe from vulkan-swrast.
readonly lavapipe_icd=/usr/share/vulkan/icd.d/lvp_icd.json

configure_vm_launchers() {
  log 'Starting LocalSend and herdr-app on CPU rendering (virgl)'
  override_launcher_env localsend 'LIBGL_ALWAYS_SOFTWARE=1'

  if [[ ! -f "$lavapipe_icd" ]]; then
    if (( skip_packages )); then
      warn "vulkan-swrast is not installed (--skip-packages); herdr-app skipped"
      return
    fi
    omarchy pkg add vulkan-swrast
  fi
  override_launcher_env herdr-app "VK_DRIVER_FILES=$lavapipe_icd"
}

# Mac<->VM clipboard (text and images) and display resizing through
# omarchy-spice-guest-tools. spice-vdagent alone is X11-only and does not sync
# reliably with Wayland apps. Built from a pinned release with makepkg; the
# package's install hook activates it for the current session.
readonly spice_tools_repo=https://github.com/riverscn/omarchy-spice-guest-tools.git
# Packaging commit for 0.1.4 (the v0.1.4 tag predates the release PKGBUILD).
readonly spice_tools_ref=2409fb1

install_spice_guest_tools() {
  local src="$HOME/src/omarchy-spice-guest-tools"

  log 'Installing omarchy-spice-guest-tools (Mac<->VM clipboard)'
  if pacman -Q omarchy-spice-guest-tools >/dev/null 2>&1; then
    printf '  ok      omarchy-spice-guest-tools %s\n' \
      "$(pacman -Q omarchy-spice-guest-tools | cut -d' ' -f2)"
  elif (( skip_packages )); then
    log 'Skipping omarchy-spice-guest-tools (--skip-packages)'
    return
  else
    if [[ -d "$src/.git" ]]; then
      git -C "$src" fetch --quiet
    else
      mkdir -p "$(dirname "$src")"
      git clone --quiet "$spice_tools_repo" "$src"
    fi
    git -C "$src" checkout --quiet "$spice_tools_ref"
    (cd "$src" && makepkg -si --needed --noconfirm)
  fi

  # udev starts spice-vdagentd.socket only when the SPICE port appears at boot,
  # so right after a fresh install the session agent has nothing to talk to.
  if ! systemctl is-active --quiet spice-vdagentd.socket; then
    sudo systemctl start spice-vdagentd.socket
    systemctl --user restart spice-vdagent.service ||
      warn 'spice-vdagent did not start; reboot, then run spice-guest-tools doctor'
  fi
}

# The package orders spice-display-bridge After=spice-vdagent, but the bridge
# only follows vdagent's journal from the moment it starts (--lines=0). UTM
# sends the window size as soon as vdagent connects at login, so the bridge
# often misses it and the display stays at 1280x800 until the window is
# resized. A user-level copy of the unit starts the bridge before vdagent.
fix_display_bridge_order() {
  local system_unit=/usr/lib/systemd/user/spice-display-bridge.service
  local unit="$HOME/.config/systemd/user/spice-display-bridge.service"
  local tmp

  log 'Starting the SPICE display bridge before spice-vdagent'
  if [[ ! -f "$system_unit" ]]; then
    warn "$system_unit not found; display resizing at login not fixed"
    return
  fi

  tmp="$(mktemp)"
  {
    printf '# Generated by cider omarchy-utm.sh from %s:\n' "$system_unit"
    printf '# starts before spice-vdagent so the login-time resize is not missed.\n'
    awk '
      /^After=/ { sub(/ spice-vdagent\.service/, ""); print; print "Before=spice-vdagent.service"; next }
      { print }
    ' "$system_unit"
  } > "$tmp"
  if [[ -f "$unit" ]] && cmp -s "$tmp" "$unit"; then
    rm -f "$tmp"
    printf '  ok      %s\n' "$unit"
    return
  fi
  mkdir -p "$(dirname "$unit")"
  [[ -f "$unit" ]] && cp "$unit" "$unit.pre-cider.$stamp"
  mv "$tmp" "$unit"
  chmod 644 "$unit"
  systemctl --user daemon-reload
  printf '  updated %s\n' "$unit"
}

# Omarchy's display scaling writes a per-output monitor rule that lands after
# spice-guest-tools' managed block and resets the display to 1280x800 on every
# Hyprland reload. A path unit runs scripts/utm_monitor_guard.sh whenever
# monitors.lua changes; it removes such rules and keeps their scale in
# omarchy_monitor_scale.
write_user_unit() {
  local unit="$1" tmp="$2"
  if [[ -f "$unit" ]] && cmp -s "$tmp" "$unit"; then
    rm -f "$tmp"
    printf '  ok      %s\n' "$unit"
    return 1
  fi
  mv "$tmp" "$unit"
  chmod 644 "$unit"
  printf '  updated %s\n' "$unit"
}

install_monitor_guard() {
  local dir="$HOME/.config/systemd/user"
  local guard="$script_dir/scripts/utm_monitor_guard.sh"
  local changed=0 tmp

  log 'Guarding monitors.lua against per-output rules (Omarchy scaling)'
  mkdir -p "$dir"

  tmp="$(mktemp)"
  cat > "$tmp" <<EOF
# Generated by cider omarchy-utm.sh.
[Unit]
Description=Remove per-output monitor rules that override SPICE display resizing

[Service]
Type=oneshot
ExecStart=/usr/bin/bash $guard
EOF
  write_user_unit "$dir/utm-monitor-guard.service" "$tmp" && changed=1

  tmp="$(mktemp)"
  cat > "$tmp" <<'EOF'
# Generated by cider omarchy-utm.sh.
[Unit]
Description=Watch monitors.lua for per-output rules that override SPICE display resizing

[Path]
PathChanged=%h/.config/hypr/monitors.lua

[Install]
WantedBy=default.target
EOF
  write_user_unit "$dir/utm-monitor-guard.path" "$tmp" && changed=1

  (( changed )) && systemctl --user daemon-reload
  systemctl --user enable --now utm-monitor-guard.path >/dev/null 2>&1 ||
    warn 'could not enable utm-monitor-guard.path'
  bash "$guard"
}

command -v omarchy >/dev/null 2>&1 || die 'omarchy command not found; this script targets Omarchy.'
is_utm_vm || die 'not a UTM VM (needs QEMU with /dev/virtio-ports/com.redhat.spice.0).'

configure_vm_launchers
install_spice_guest_tools
fix_display_bridge_order
install_monitor_guard

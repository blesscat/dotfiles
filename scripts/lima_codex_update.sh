#!/bin/bash
set -euo pipefail

readonly instance='dev'
readonly codex_home='/Users/blesscat/.codex'
readonly installer_url='https://chatgpt.com/codex/install.sh'

run_on_macos() {
  local script_dir
  local repo_dir

  [[ $# -eq 0 ]] || {
    printf 'Usage: %s\n' "$0" >&2
    exit 2
  }

  command -v limactl >/dev/null 2>&1 || {
    printf '%s\n' 'limactl is required. Run ~/.cider/lima_init.sh first.' >&2
    exit 1
  }

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  repo_dir="$(cd -- "$script_dir/.." && pwd -P)"

  "$repo_dir/scripts/lima_create.sh" "$instance"
  limactl shell "$instance" -- "$repo_dir/scripts/lima_codex_update.sh" --guest
}

find_current_codex() {
  local candidate

  for candidate in \
    "$codex_home/packages/standalone/current/codex" \
    "$codex_home/packages/standalone/current/bin/codex"; do
    if [[ -x "$candidate" ]] && "$candidate" --version >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

run_in_guest() {
  local installer_path
  local codex_binary
  local current_release

  [[ $# -eq 1 && "$1" == '--guest' ]] || {
    printf '%s\n' 'This Linux-side entry point is managed by the macOS wrapper.' >&2
    exit 2
  }
  [[ "$(uname -s)" == 'Linux' ]] || {
    printf '%s\n' 'The guest updater must run inside Linux.' >&2
    exit 1
  }
  command -v curl >/dev/null 2>&1 || {
    printf '%s\n' 'curl is required inside the Lima guest.' >&2
    exit 1
  }

  export CODEX_HOME="$codex_home"
  export CODEX_INSTALL_DIR="$HOME/.local/bin"
  export CODEX_NON_INTERACTIVE=1
  export TMPDIR="$HOME/.local/state/codex-tmp"
  install -d -m 0700 "$TMPDIR"

  # Refresh the durable overlay definition before writing through the shared
  # CODEX_HOME path. The bind mount keeps Linux releases off the macOS volume.
  sudo install -m 0755 \
    /Users/blesscat/.cider/scripts/lima_codex_overlay.sh \
    /usr/local/sbin/codex-lima-overlay
  sudo install -m 0644 \
    /Users/blesscat/.cider/lima/codex-overlay.service \
    /etc/systemd/system/codex-lima-overlay.service
  sudo install -m 0644 \
    /Users/blesscat/.cider/lima/codex-app-server.service \
    /etc/systemd/system/codex-app-server.service
  sudo systemctl daemon-reload
  sudo systemctl enable codex-lima-overlay.service codex-app-server.service >/dev/null
  sudo systemctl restart codex-lima-overlay.service

  if ! mountpoint -q "$codex_home/packages/standalone"; then
    printf '%s\n' 'Refusing to update: the Lima Codex standalone overlay is not mounted.' >&2
    exit 1
  fi

  installer_path="$(mktemp "$TMPDIR/codex-install.XXXXXX")"
  trap 'rm -f "${installer_path:-}"' EXIT
  printf '%s\n' 'Downloading the official Codex installer...'
  curl -fsSL "$installer_url" -o "$installer_path"
  sh "$installer_path"
  rm -f "$installer_path"
  trap - EXIT

  codex_binary="$(find_current_codex)" || {
    printf '%s\n' 'The installer completed, but no runnable Linux Codex binary was found.' >&2
    exit 1
  }
  current_release="$(readlink -f "$codex_home/packages/standalone/current")"
  case "$current_release" in
    "$codex_home/packages/standalone/releases/"*) ;;
    *)
      printf 'The installer selected an unexpected release path: %s\n' "$current_release" >&2
      exit 1
      ;;
  esac

  # A plain systemd restart only calls `daemon start`, which may leave an old
  # process alive. Restart explicitly with the newly selected CLI first.
  "$codex_binary" app-server daemon restart
  sudo systemctl restart codex-app-server.service

  printf '\n%s\n' 'Lima Codex update complete.'
  "$codex_binary" --version
  "$codex_binary" app-server daemon version
  printf 'Linux release: %s\n' "$current_release"
}

case "$(uname -s)" in
  Darwin) run_on_macos "$@" ;;
  Linux) run_in_guest "$@" ;;
  *) printf 'Unsupported operating system: %s\n' "$(uname -s)" >&2; exit 1 ;;
esac

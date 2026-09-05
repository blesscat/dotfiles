#!/bin/bash
set -euo pipefail

readonly instance='dev'
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
  local codex_home="$1"
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
  local bootstrap_output
  local codex_home
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

  # Codex state is intentionally guest-local. Clear the legacy value that used
  # to redirect Linux sessions into the macOS-mounted ~/.codex directory.
  unset CODEX_HOME
  codex_home="$(cd -- "$HOME" && pwd -P)/.codex"
  export CODEX_INSTALL_DIR="$HOME/.local/bin"
  export CODEX_NON_INTERACTIVE=1
  export TMPDIR="$HOME/.local/state/codex-tmp"
  install -d -m 0700 "$TMPDIR"

  installer_path="$(mktemp "$TMPDIR/codex-install.XXXXXX")"
  trap 'rm -f "${installer_path:-}"' EXIT
  printf '%s\n' 'Downloading the official Codex installer...'
  curl -fsSL "$installer_url" -o "$installer_path"
  sh "$installer_path"
  rm -f "$installer_path"
  trap - EXIT

  codex_binary="$(find_current_codex "$codex_home")" || {
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

  if bootstrap_output="$("$codex_binary" app-server daemon bootstrap --remote-control 2>&1)"; then
    [[ -z "$bootstrap_output" ]] || printf '%s\n' "$bootstrap_output"
  elif [[ "$bootstrap_output" == *'app server is running but is not managed by codex app-server daemon'* ]]; then
    printf '%s\n' \
      'Codex app-server is already active for an SSH session; leaving that session in control.'
  else
    printf '%s\n' "$bootstrap_output" >&2
    exit 1
  fi

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

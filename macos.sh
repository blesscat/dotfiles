#!/bin/bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir
readonly brewfile="$script_dir/Brewfile"
readonly brew_setup_script="${CIDER_BREW_SETUP_SCRIPT:-$script_dir/scripts/brew_setup.sh}"
readonly notification_installer="${CIDER_CODEX_NOTIFY_INSTALLER:-$script_dir/codex-notify/install.zsh}"
readonly brew_candidates="${CIDER_BREW_CANDIDATES:-/opt/homebrew/bin/brew:/usr/local/bin/brew}"

if [[ ! -r "$brew_setup_script" ]]; then
  /usr/bin/printf 'macos bootstrap: Homebrew setup script is unavailable: %s\n' \
    "$brew_setup_script" >&2
  exit 1
fi
if [[ ! -f "$brewfile" ]]; then
  /usr/bin/printf 'macos bootstrap: Brewfile is unavailable: %s\n' \
    "$brewfile" >&2
  exit 1
fi
if [[ ! -x "$notification_installer" ]]; then
  /usr/bin/printf 'macos bootstrap: notification installer is unavailable: %s\n' \
    "$notification_installer" >&2
  exit 1
fi

brew_was_on_path=0
if command -v brew >/dev/null 2>&1; then
  brew_was_on_path=1
fi

# shellcheck source=scripts/brew_setup.sh
source "$brew_setup_script"

brew_bin="$(command -v brew 2>/dev/null || true)"
if [[ -z "$brew_bin" ]]; then
  old_ifs="$IFS"
  IFS=':'
  read -r -a candidate_paths <<< "$brew_candidates"
  IFS="$old_ifs"
  for candidate in "${candidate_paths[@]}"; do
    if [[ -x "$candidate" ]]; then
      brew_bin="$candidate"
      break
    fi
  done
fi

if [[ -z "$brew_bin" || ! -x "$brew_bin" ]]; then
  /usr/bin/printf '%s\n' \
    'macos bootstrap: Homebrew remains unavailable after setup.' >&2
  exit 1
fi

if (( brew_was_on_path == 0 )); then
  shell_environment="$("$brew_bin" shellenv)"
  eval "$shell_environment"
fi

"$brew_bin" bundle install "--file=$brewfile" --no-upgrade
/usr/bin/printf 'macos bootstrap: running notification installer: %s\n' \
  "$notification_installer"
"$notification_installer"

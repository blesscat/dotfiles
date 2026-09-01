#!/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
action="${1:-status}"
instance="${2:-dev}"

case "$instance" in
  dev|agent) ;;
  *) printf 'Usage: %s <start|stop|status|destroy> [dev|agent]\n' "$0" >&2; exit 2 ;;
esac
command -v limactl >/dev/null 2>&1 || { printf '%s\n' 'limactl is required. Run scripts/lima_install.sh.' >&2; exit 1; }

case "$action" in
  start) "$script_dir/lima_create.sh" "$instance" ;;
  stop) limactl stop "$instance" ;;
  status) limactl list "$instance" ;;
  destroy)
    printf 'This deletes the Lima VM and its guest-side Docker volumes (%s). Type the instance name to continue: ' "$instance" >&2
    read -r confirmation
    if [[ "$confirmation" != "$instance" ]]; then
      printf '%s\n' 'Aborted; the instance was not deleted.' >&2
      exit 1
    fi
    limactl delete "$instance"
    ;;
  *) printf 'Usage: %s <start|stop|status|destroy> [dev|agent]\n' "$0" >&2; exit 2 ;;
esac

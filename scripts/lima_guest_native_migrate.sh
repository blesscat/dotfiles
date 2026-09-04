#!/bin/bash
set -euo pipefail

readonly instance='dev'
readonly timestamp="${LIMA_MIGRATION_TIMESTAMP:-$(date '+%Y%m%d-%H%M%S')}"
readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly repo_dir="$(cd -- "$script_dir/.." && pwd -P)"
readonly instance_dir="${LIMA_INSTANCE_DIR:-$HOME/.lima/$instance}"
readonly live_config="$instance_dir/lima.yaml"
readonly backup_dir="$instance_dir/config-backups"
readonly config_backup="$backup_dir/lima.yaml.$timestamp"

[[ $# -eq 0 ]] || {
  printf 'Usage: %s\n' "$0" >&2
  exit 2
}
[[ "$timestamp" =~ ^[0-9]{8}-[0-9]{6}$ ]] || {
  printf 'Invalid migration timestamp: %s\n' "$timestamp" >&2
  exit 2
}
[[ "$(uname -s)" == 'Darwin' ]] || {
  printf '%s\n' 'The existing-VM migration must run on macOS.' >&2
  exit 1
}
command -v limactl >/dev/null 2>&1 || {
  printf '%s\n' 'limactl is required.' >&2
  exit 1
}
if ! limactl list --format '{{.Name}}' | grep -Fxq "$instance"; then
  printf 'Lima instance does not exist: %s\n' "$instance" >&2
  exit 1
fi
[[ -f "$live_config" ]] || {
  printf 'Live Lima configuration was not found: %s\n' "$live_config" >&2
  exit 1
}

mkdir -p "$backup_dir"
cp -p "$live_config" "$config_backup"

vm_stopped=false
configuration_edited=false
guest_native_committed=false
migration_complete=false

rollback_on_failure() {
  local status=$?
  trap - EXIT
  if [[ "$status" -ne 0 && "$migration_complete" != true ]]; then
    if [[ "$guest_native_committed" == true ]]; then
      printf '\nThe mount migration succeeded, but a later setup step failed.\n' >&2
      printf '%s\n' 'The guest-native layout was preserved; rerun this script to finish setup.' >&2
    else
      printf '\nMigration failed; restoring the previous Lima configuration.\n' >&2
      if [[ "$vm_stopped" != true ]]; then
        limactl stop "$instance" >/dev/null 2>&1 || true
      fi
      if [[ "$configuration_edited" == true ]]; then
        cp -p "$config_backup" "$live_config"
      fi
      limactl start "$instance" >/dev/null 2>&1 || true
      printf 'Restored configuration backup: %s\n' "$config_backup" >&2
    fi
  fi
  exit "$status"
}
trap rollback_on_failure EXIT

printf '%s\n' 'Starting the existing Lima VM when needed.'
limactl start "$instance"

printf '%s\n' 'Disabling the legacy shared-Codex services.'
limactl shell "$instance" -- sh -lc \
  'sudo systemctl disable --now codex-app-server.service codex-lima-overlay.service >/dev/null 2>&1 || true'

printf '%s\n' 'Stopping Lima before changing host mounts.'
limactl stop "$instance"
vm_stopped=true

printf '%s\n' 'Keeping only the Cider mount and removing legacy environment overrides.'
limactl edit --tty=false "$instance" \
  --set '.mounts = [{"location": "~/.cider", "writable": true}]' \
  --set 'del(.env.CODEX_HOME)' \
  --set 'del(.env.TMPDIR)' \
  --set '.ssh.forwardAgent = true' \
  --set '.provision = [.provision[] | select(.mode == "system")]'
configuration_edited=true

limactl start "$instance"
vm_stopped=false

printf '%s\n' 'Creating guest-native project and Codex directories.'
limactl shell "$instance" -- /Users/blesscat/.cider/scripts/lima_guest_layout.sh
limactl shell "$instance" -- sh -lc \
  'test -L "$HOME/.cider" && test "$(readlink "$HOME/.cider")" = /Users/blesscat/.cider && test -d "$HOME/doc" && test ! -L "$HOME/doc" && test -d "$HOME/.codex" && test ! -L "$HOME/.codex" && test -z "${CODEX_HOME-}"'
guest_native_committed=true

printf '%s\n' 'Moving obsolete Codex service files into a recoverable guest backup.'
limactl shell "$instance" -- sh -lc "
  set -eu
  backup='/var/lib/cider-migration-backups/$timestamp'
  found=false
  for source in \
    /etc/systemd/system/codex-app-server.service \
    /etc/systemd/system/codex-lima-overlay.service \
    /usr/local/sbin/codex-lima-overlay; do
    if sudo test -e \"\$source\"; then
      sudo install -d -m 0700 \"\$backup\"
      sudo mv \"\$source\" \"\$backup/\"
      found=true
    fi
  done
  if [ \"\$found\" = true ]; then
    sudo systemctl daemon-reload
  fi
"

printf '%s\n' 'Installing and bootstrapping guest-local Codex.'
limactl shell "$instance" -- sh -lc '$HOME/.cider/scripts/lima_codex_update.sh --guest'

printf '%s\n' 'Refreshing the macOS Docker context.'
"$repo_dir/scripts/lima_docker_context.sh" "$instance"

migration_complete=true
trap - EXIT
printf '\nMigration complete.\nLima configuration backup: %s\n' "$config_backup"
printf 'Legacy guest service backup: /var/lib/cider-migration-backups/%s\n' "$timestamp"

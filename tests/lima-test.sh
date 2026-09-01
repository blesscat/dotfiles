#!/bin/bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
for file in "$repo_dir/lima/dev.yaml" "$repo_dir/lima/agent.yaml" "$repo_dir/lima_init.sh" "$repo_dir/scripts/lima_install.sh" "$repo_dir/scripts/lima_create.sh" "$repo_dir/scripts/lima_docker_context.sh" "$repo_dir/scripts/lima_lifecycle.sh"; do
  [[ -r "$file" ]] || { printf 'Missing required file: %s\n' "$file" >&2; exit 1; }
done
bash -n "$repo_dir/lima_init.sh" "$repo_dir/scripts/lima_install.sh" "$repo_dir/scripts/lima_create.sh" "$repo_dir/scripts/lima_docker_context.sh" "$repo_dir/scripts/lima_lifecycle.sh"
grep -Fq '"$install_script"' "$repo_dir/lima_init.sh"
grep -Fq '"$create_script" dev' "$repo_dir/lima_init.sh"
grep -Fq '"$docker_context_script" dev' "$repo_dir/lima_init.sh"
grep -Fq '"$lifecycle_script" autostart dev' "$repo_dir/lima_init.sh"
install_line="$(grep -nF '"$install_script"' "$repo_dir/lima_init.sh" | head -n1 | cut -d: -f1)"
create_line="$(grep -nF '"$create_script" dev' "$repo_dir/lima_init.sh" | head -n1 | cut -d: -f1)"
context_line="$(grep -nF '"$docker_context_script" dev' "$repo_dir/lima_init.sh" | head -n1 | cut -d: -f1)"
autostart_line="$(grep -nF '"$lifecycle_script" autostart dev' "$repo_dir/lima_init.sh" | head -n1 | cut -d: -f1)"
(( install_line < create_line && create_line < context_line && context_line < autostart_line ))
grep -Fq 'minimumLimaVersion: 2.2.0' "$repo_dir/lima/dev.yaml"
grep -Fq 'minimumLimaVersion: 2.2.0' "$repo_dir/lima/agent.yaml"
grep -Fq 'location: "~/doc"' "$repo_dir/lima/dev.yaml"
grep -Fq 'mountPoint: "{{.Home}}/doc"' "$repo_dir/lima/dev.yaml"
grep -Fq 'location: "~/.cider"' "$repo_dir/lima/dev.yaml"
grep -Fq 'mountPoint: "{{.Home}}/.cider"' "$repo_dir/lima/dev.yaml"
grep -Fq 'mounts: []' "$repo_dir/lima/agent.yaml"
grep -Fq 'writable: true' "$repo_dir/lima/dev.yaml"
grep -Fq 'system: false' "$repo_dir/lima/dev.yaml"
grep -Fq 'hostSocket: "{{.Dir}}/sock/docker.sock"' "$repo_dir/lima/dev.yaml"
grep -Fq 'hostSocket: "{{.Dir}}/sock/docker.sock"' "$repo_dir/lima/agent.yaml"
if grep -Eq '^[[:space:]]+- guestPort' "$repo_dir/lima/dev.yaml"; then
  printf '%s\n' 'Development TCP ports should use Lima dynamic forwarding.' >&2
  exit 1
fi
grep -Fq 'docker_host=' "$repo_dir/scripts/lima_docker_context.sh"
grep -Fq 'instance_created=false' "$repo_dir/scripts/lima_create.sh"
grep -Fq 'instance_created=true' "$repo_dir/scripts/lima_create.sh"
grep -Fq 'if [[ "$instance_created" == true ]]; then' "$repo_dir/scripts/lima_create.sh"
grep -Fq 'limactl stop "$instance"' "$repo_dir/scripts/lima_create.sh"

lima_test_tmp_dir="$(mktemp -d)"
trap 'rm -rf "$lima_test_tmp_dir"' EXIT
fake_lima_bin="$lima_test_tmp_dir/bin"
mkdir -p "$fake_lima_bin"
printf '%s\n' \
  '#!/bin/bash' \
  'set -euo pipefail' \
  'case "${1:-}" in' \
  '  list)' \
  '    if [[ "${FAKE_INSTANCE_EXISTS:-false}" == true ]]; then printf "%s\\n" dev; fi' \
  '    ;;' \
  '  start|stop)' \
  '    printf "%s\\n" "$1" >> "$FAKE_CALL_LOG"' \
  '    ;;' \
  '  *)' \
  '    printf "Unexpected fake limactl command: %s\\n" "$*" >&2' \
  '    exit 2' \
  '    ;;' \
  'esac' > "$fake_lima_bin/limactl"
chmod 755 "$fake_lima_bin/limactl"

fresh_calls="$lima_test_tmp_dir/fresh-calls"
PATH="$fake_lima_bin:/usr/bin:/bin" \
  FAKE_INSTANCE_EXISTS=false \
  FAKE_CALL_LOG="$fresh_calls" \
  "$repo_dir/scripts/lima_create.sh" dev >/dev/null
[[ "$(<"$fresh_calls")" == $'start\nstop\nstart' ]] || {
  printf '%s\n' 'New Lima instances must refresh the hostagent after provisioning.' >&2
  exit 1
}

existing_calls="$lima_test_tmp_dir/existing-calls"
PATH="$fake_lima_bin:/usr/bin:/bin" \
  FAKE_INSTANCE_EXISTS=true \
  FAKE_CALL_LOG="$existing_calls" \
  "$repo_dir/scripts/lima_create.sh" dev >/dev/null
[[ "$(<"$existing_calls")" == 'start' ]] || {
  printf '%s\n' 'Existing Lima instances must not be restarted by the create helper.' >&2
  exit 1
}

grep -Fq 'limactl delete' "$repo_dir/scripts/lima_lifecycle.sh"
grep -Fq 'limactl autostart enable --condition=login' "$repo_dir/scripts/lima_lifecycle.sh"
grep -Fq 'docker context update' "$repo_dir/scripts/lima_docker_context.sh"
grep -Fq '.env.*' "$repo_dir/.gitignore"
grep -Fq '"$guest_home/doc/autoIQ/.cider-lima-backups:/backup"' "$repo_dir/README.md"
grep -Fq 'case "$action"' "$repo_dir/scripts/lima_lifecycle.sh"
if grep -Eq '/var/lib/(postgresql|mysql)|location:.*db' "$repo_dir/lima/dev.yaml" "$repo_dir/lima/agent.yaml"; then
  printf '%s\n' 'Database data must not be configured as a host mount.' >&2
  exit 1
fi
printf '%s\n' 'Lima static checks passed.'

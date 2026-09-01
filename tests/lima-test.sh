#!/bin/bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
for file in "$repo_dir/lima/dev.yaml" "$repo_dir/lima/agent.yaml" "$repo_dir/scripts/lima_install.sh" "$repo_dir/scripts/lima_create.sh" "$repo_dir/scripts/lima_docker_context.sh" "$repo_dir/scripts/lima_lifecycle.sh"; do
  [[ -r "$file" ]] || { printf 'Missing required file: %s\n' "$file" >&2; exit 1; }
done
bash -n "$repo_dir/scripts/lima_install.sh" "$repo_dir/scripts/lima_create.sh" "$repo_dir/scripts/lima_docker_context.sh" "$repo_dir/scripts/lima_lifecycle.sh"
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

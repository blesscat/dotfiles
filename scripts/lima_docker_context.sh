#!/bin/bash
set -euo pipefail

instance="${1:-dev}"
context="${2:-lima-$instance}"
command -v limactl >/dev/null 2>&1 || { printf '%s\n' 'limactl is required. Run scripts/lima_install.sh.' >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { printf '%s\n' 'Docker CLI is required. Run scripts/lima_install.sh.' >&2; exit 1; }
if ! limactl list --format '{{.Name}}' | grep -Fxq "$instance"; then
  printf 'Lima instance does not exist: %s\n' "$instance" >&2
  printf 'Run scripts/lima_create.sh %s first.\n' "$instance" >&2
  exit 1
fi

docker_host="$(limactl list "$instance" --format='unix://{{.Dir}}/sock/docker.sock')"
if [[ -z "$docker_host" ]]; then
  printf 'Could not determine Docker socket for Lima instance: %s\n' "$instance" >&2
  exit 1
fi
if docker context inspect "$context" >/dev/null 2>&1; then
  docker context update "$context" --docker "host=$docker_host"
else
  docker context create "$context" --docker "host=$docker_host" >/dev/null
fi
docker context use "$context" >/dev/null
docker info >/dev/null
printf 'Docker context is active and healthy: %s -> %s\n' "$context" "$instance"

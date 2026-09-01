#!/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(cd -- "$script_dir/.." && pwd -P)"
instance="${1:-dev}"
case "$instance" in
  dev|agent) ;;
  *) printf 'Usage: %s [dev|agent]\n' "$0" >&2; exit 2 ;;
esac
command -v limactl >/dev/null 2>&1 || { printf '%s\n' 'limactl is required. Run scripts/lima_install.sh.' >&2; exit 1; }
config="$repo_dir/lima/$instance.yaml"
[[ -r "$config" ]] || { printf 'Missing Lima configuration: %s\n' "$config" >&2; exit 1; }

if limactl list --format '{{.Name}}' | grep -Fxq "$instance"; then
  limactl start "$instance"
else
  limactl start --name="$instance" "$config"
fi
printf 'Lima instance is ready: %s\n' "$instance"

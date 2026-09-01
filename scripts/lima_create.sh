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

instance_created=false
if limactl list --format '{{.Name}}' | grep -Fxq "$instance"; then
  limactl start "$instance"
else
  limactl start --name="$instance" "$config"
  instance_created=true
fi

# Lima starts its persistent SSH ControlMaster before the system provisioning
# script has finished. Docker's socket is root:docker, so the forwarding
# connection created during a first boot can retain the user's old group list
# even though usermod has already added the user to docker. Recreate the
# hostagent connection once, after provisioning, so the forwarded socket is
# usable by the host Docker CLI. Existing instances are left untouched.
if [[ "$instance_created" == true ]]; then
  printf '%s\n' 'Refreshing the newly provisioned Lima hostagent connection for Docker socket access.'
  limactl stop "$instance"
  limactl start "$instance"
fi
printf 'Lima instance is ready: %s\n' "$instance"

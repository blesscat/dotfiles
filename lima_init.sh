#!/bin/bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly repo_dir
readonly install_script="$repo_dir/scripts/lima_install.sh"
readonly create_script="$repo_dir/scripts/lima_create.sh"
readonly docker_context_script="$repo_dir/scripts/lima_docker_context.sh"
readonly lifecycle_script="$repo_dir/scripts/lima_lifecycle.sh"

for script in "$install_script" "$create_script" "$docker_context_script" "$lifecycle_script"; do
  if [[ ! -x "$script" ]]; then
    printf 'Lima init: required script is unavailable or not executable: %s\n' \
      "$script" >&2
    exit 1
  fi
done

printf '%s\n' 'Lima init: installing host prerequisites.'
"$install_script"

printf '%s\n' 'Lima init: creating or starting the dev VM.'
"$create_script" dev

printf '%s\n' 'Lima init: configuring the lima-dev Docker context.'
"$docker_context_script" dev

printf '%s\n' 'Lima init: enabling Lima autostart at macOS login.'
"$lifecycle_script" autostart dev

printf '%s\n' 'Lima init: dev environment is ready and autostart is enabled.'

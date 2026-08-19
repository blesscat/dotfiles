#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
source_dir="${CIDER_AGENTS_SKILLS_SOURCE:-$repo_root/.agents/skills}"
home_dir="${HOME:-}"

agents_dir="$home_dir/.agents"
target_dir="$agents_dir/skills"
backup_dir=''

error() {
  printf 'agents skills setup: %s\n' "$*" >&2
}

validate_source() {
  local -a skill_dirs=()
  local skill_dir

  if [[ -z "$home_dir" ]]; then
    error 'HOME must be set'
    return 1
  fi

  if [[ ! -d "$source_dir" ]]; then
    error "managed source directory is unavailable: $source_dir"
    return 1
  fi

  shopt -s nullglob
  skill_dirs=("$source_dir"/*/)
  shopt -u nullglob

  if (( ${#skill_dirs[@]} == 0 )); then
    error "managed source contains no skill directories: $source_dir"
    return 1
  fi

  for skill_dir in "${skill_dirs[@]}"; do
    if [[ ! -f "$skill_dir/SKILL.md" ]]; then
      error "skill directory is missing SKILL.md: $skill_dir"
      return 1
    fi
  done

  if [[ -e "$source_dir/.skill-lock.json" ]]; then
    error "generated lock state must not be inside the managed source: $source_dir/.skill-lock.json"
    return 1
  fi
}

validate_link() {
  local actual_target

  if [[ ! -L "$target_dir" ]]; then
    error "managed path is not a symbolic link: $target_dir"
    return 1
  fi

  actual_target="$(readlink "$target_dir")"
  if [[ "$actual_target" != "$source_dir" ]]; then
    error "managed path points to '$actual_target' instead of '$source_dir'"
    return 1
  fi

  if [[ ! -d "$target_dir" ]]; then
    error "managed path does not resolve to a directory: $target_dir"
    return 1
  fi
}

next_backup_path() {
  local timestamp
  local candidate
  local suffix=0

  timestamp="$(date '+%Y%m%d%H%M%S')"
  candidate="$agents_dir/skills.backup-$timestamp"
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    suffix=$((suffix + 1))
    candidate="$agents_dir/skills.backup-$timestamp-$suffix"
  done
  printf '%s\n' "$candidate"
}

restore_backup() {
  if [[ -z "$backup_dir" ]]; then
    return 0
  fi

  if [[ -e "$target_dir" || -L "$target_dir" ]]; then
    if [[ ! -L "$target_dir" ]]; then
      error "cannot restore backup because the target is not a link: $target_dir"
      return 1
    fi
    unlink "$target_dir"
  fi

  if ! mv "$backup_dir" "$target_dir"; then
    error "could not restore backup '$backup_dir' to '$target_dir'"
    return 1
  fi
  backup_dir=''
}

main() {
  if ! validate_source; then
    exit 1
  fi

  if [[ -L "$agents_dir" ]]; then
    error "user agents directory must not be a symbolic link: $agents_dir"
    exit 1
  fi
  mkdir -p "$agents_dir"

  if [[ -L "$target_dir" && "$(readlink "$target_dir")" == "$source_dir" ]]; then
    validate_link
    printf 'agents skills setup: already linked to %s\n' "$source_dir"
    exit 0
  fi

  if [[ -e "$target_dir" || -L "$target_dir" ]]; then
    backup_dir="$(next_backup_path)"
    if ! mv "$target_dir" "$backup_dir"; then
      error "could not move the existing skill path to '$backup_dir'"
      exit 1
    fi
    printf 'agents skills setup: backed up existing skills to %s\n' "$backup_dir"
  fi

  if ! ln -s "$source_dir" "$target_dir"; then
    error "could not create managed link: $target_dir"
    if ! restore_backup; then
      error 'the previous skill path could not be restored; inspect the backup above'
    fi
    exit 1
  fi

  if ! validate_link; then
    error 'managed link validation failed'
    unlink "$target_dir" || true
    if ! restore_backup; then
      error 'the previous skill path could not be restored; inspect the backup above'
    fi
    exit 1
  fi

  printf 'agents skills setup: linked %s to %s\n' "$target_dir" "$source_dir"
  if [[ -n "$backup_dir" ]]; then
    printf 'agents skills setup: previous skills remain at %s\n' "$backup_dir"
  fi
}

main "$@"

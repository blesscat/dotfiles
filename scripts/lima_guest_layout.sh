#!/bin/bash
set -euo pipefail

readonly guest_home="${LIMA_GUEST_HOME:-${HOME:?HOME is required}}"
readonly cider_source="${LIMA_CIDER_SOURCE:-/Users/blesscat/.cider}"
readonly legacy_doc_source="${LIMA_LEGACY_DOC_SOURCE:-/Users/blesscat/doc}"
readonly legacy_codex_source="${LIMA_LEGACY_CODEX_SOURCE:-/Users/blesscat/.codex}"

fail() {
  printf 'Lima guest layout: %s\n' "$1" >&2
  exit 1
}

ensure_private_directory() {
  local path="$1"
  local legacy_source="$2"
  local current_target

  if [[ -L "$path" ]]; then
    current_target="$(readlink "$path")"
    [[ "$current_target" == "$legacy_source" ]] || \
      fail "refusing to replace unexpected symlink: $path -> $current_target"
    unlink "$path"
  elif [[ -e "$path" && ! -d "$path" ]]; then
    fail "refusing to replace non-directory path: $path"
  fi

  mkdir -p "$path"
}

ensure_cider_link() {
  local path="$guest_home/.cider"
  local current_target

  [[ -d "$cider_source" ]] || fail "mounted Cider source is unavailable: $cider_source"

  if [[ -L "$path" ]]; then
    current_target="$(readlink "$path")"
    [[ "$current_target" == "$cider_source" ]] || \
      fail "refusing to replace unexpected symlink: $path -> $current_target"
    return
  fi

  if [[ -e "$path" ]]; then
    [[ -d "$path" ]] || fail "refusing to replace non-directory path: $path"
    rmdir "$path" >/dev/null 2>&1 || \
      fail "refusing to replace non-empty directory: $path"
  fi

  ln -s "$cider_source" "$path"
}

ensure_cider_link
ensure_private_directory "$guest_home/doc" "$legacy_doc_source"
ensure_private_directory "$guest_home/.codex" "$legacy_codex_source"
chmod 700 "$guest_home/.codex"

printf 'Lima guest layout: %s is guest-local; %s links to %s\n' \
  "$guest_home/doc" "$guest_home/.cider" "$cider_source"

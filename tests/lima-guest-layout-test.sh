#!/bin/bash

set -euo pipefail

readonly test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly repo_dir="$(cd -- "$test_dir/.." && pwd -P)"
readonly script="$repo_dir/scripts/lima_guest_layout.sh"
readonly tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

readonly guest_home="$tmp_dir/guest-home"
readonly cider_source="$tmp_dir/host/.cider"
readonly legacy_doc_source="$tmp_dir/host/doc"
readonly legacy_codex_source="$tmp_dir/host/.codex"

mkdir -p "$guest_home" "$cider_source" "$legacy_doc_source" "$legacy_codex_source"
ln -s "$legacy_doc_source" "$guest_home/doc"
ln -s "$legacy_codex_source" "$guest_home/.codex"

LIMA_GUEST_HOME="$guest_home" \
LIMA_CIDER_SOURCE="$cider_source" \
LIMA_LEGACY_DOC_SOURCE="$legacy_doc_source" \
LIMA_LEGACY_CODEX_SOURCE="$legacy_codex_source" \
  "$script"

[[ -L "$guest_home/.cider" ]] || fail 'guest .cider is not a symlink'
[[ "$(readlink "$guest_home/.cider")" == "$cider_source" ]] || \
  fail 'guest .cider does not target the mounted host Cider repo'
[[ -d "$guest_home/doc" && ! -L "$guest_home/doc" ]] || \
  fail 'guest doc is not a guest-local directory'
[[ -d "$guest_home/.codex" && ! -L "$guest_home/.codex" ]] || \
  fail 'guest .codex is not a guest-local directory'
[[ "$(stat -f '%Lp' "$guest_home/.codex" 2>/dev/null || stat -c '%a' "$guest_home/.codex")" == '700' ]] || \
  fail 'guest .codex is not private'
[[ -d "$legacy_doc_source" && -d "$legacy_codex_source" ]] || \
  fail 'legacy host sources were modified'

LIMA_GUEST_HOME="$guest_home" \
LIMA_CIDER_SOURCE="$cider_source" \
LIMA_LEGACY_DOC_SOURCE="$legacy_doc_source" \
LIMA_LEGACY_CODEX_SOURCE="$legacy_codex_source" \
  "$script"

printf '%s\n' 'PASS: Lima guest-native layout'

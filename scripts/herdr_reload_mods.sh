#!/usr/bin/env bash
# Reload Herdr mods that are symlinked from this repository.
#
# Herdr hot-reloads a mod when files under ~/.config/herdr-app/mods change,
# but its watcher does not follow symlinks. Editing a tracked mod here does not
# reload it. Recreating the mod's symlink does, so run this after editing.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
mods_dir="$HOME/.config/herdr-app/mods"

reloaded=0
for link in "$mods_dir"/*; do
  [[ -L "$link" ]] || continue
  target="$(readlink "$link")"
  [[ "$target" == "$repo_root"/* ]] || continue
  ln -sfn "$target" "$link"
  printf 'Reloaded %s\n' "$(basename "$link")"
  reloaded=$((reloaded + 1))
done

if [[ $reloaded -eq 0 ]]; then
  printf 'No Herdr mods are symlinked from %s\n' "$repo_root" >&2
  exit 1
fi

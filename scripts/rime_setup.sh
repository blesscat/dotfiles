#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"

case "$(uname -s)" in
  Darwin)
    rime_dir="$HOME/Library/Rime"
    ;;
  Linux)
    rime_dir="$HOME/.local/share/fcitx5/rime"
    ;;
  *)
    printf 'Unsupported operating system: %s\n' "$(uname -s)" >&2
    exit 2
    ;;
esac

for name in default.custom.yaml bopomofo_tw.custom.yaml rime_ice.custom.yaml; do
  if [[ ! -f "$repo_root/rime/$name" ]]; then
    printf 'Missing shared Rime config: %s\n' "$repo_root/rime/$name" >&2
    exit 1
  fi
done

shared_data_dir=""
if [[ "$(uname -s)" == Linux ]]; then
  if ! command -v rime_deployer >/dev/null 2>&1; then
    printf '%s\n' 'rime_deployer is required to deploy the Linux configuration.' >&2
    exit 1
  fi

  for candidate in /usr/share/rime-data /usr/local/share/rime-data; do
    if [[ -d "$candidate" ]]; then
      shared_data_dir="$candidate"
      break
    fi
  done

  if [[ -z "$shared_data_dir" ]]; then
    printf '%s\n' 'Could not find the Rime shared data directory.' >&2
    exit 1
  fi
fi

mkdir -p "$rime_dir"
backup_stamp="$(date +%Y%m%d-%H%M%S)"

for name in default.custom.yaml bopomofo_tw.custom.yaml rime_ice.custom.yaml; do
  source_file="$repo_root/rime/$name"
  destination="$rime_dir/$name"

  if [[ -L "$destination" ]] && [[ "$(readlink "$destination")" == "$source_file" ]]; then
    continue
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    backup_path="$destination.pre-cider.$backup_stamp"
    if [[ -e "$backup_path" || -L "$backup_path" ]]; then
      backup_path="$backup_path.$$"
    fi
    mv "$destination" "$backup_path"
    printf 'Backed up %s to %s\n' "$destination" "$backup_path"
  fi

  ln -s "$source_file" "$destination"
  printf 'Linked %s -> %s\n' "$destination" "$source_file"
done

if [[ "$(uname -s)" == Linux ]]; then
  rime_deployer --build "$rime_dir" "$shared_data_dir"
  printf 'Rime deployed from %s using %s\n' "$rime_dir" "$shared_data_dir"
else
  printf 'Configs linked into %s. Deploy from the Squirrel menu.\n' "$rime_dir"
fi

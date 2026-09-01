#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' 'Lima host setup requires macOS.' >&2
  exit 1
fi
if ! command -v brew >/dev/null 2>&1; then
  printf '%s\n' 'Homebrew is required. Run ./macos.sh first or install Homebrew.' >&2
  exit 1
fi

brew install lima docker docker-compose

for command_name in limactl docker rsync; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Lima host setup: required command is unavailable: %s\n' "$command_name" >&2
    exit 1
  fi
done
printf '%s\n' 'Lima host prerequisites are ready. No VM was started.'

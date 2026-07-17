#!/usr/bin/env bash

set -euo pipefail

readonly yazelix_ref='github:luccahuguet/yazelix'

if command -v yzx >/dev/null 2>&1; then
  printf 'Yazelix is already available: %s\n' "$(command -v yzx)"
  exit 0
fi

nix_bin="$(command -v nix 2>/dev/null || true)"

if [[ -z "$nix_bin" || ! -x "$nix_bin" ]]; then
  printf '%s\n' \
    'Yazelix installation deferred: Nix was not found.' >&2
  printf '%s\n' \
    'Install Nix with flakes enabled, then rerun ./scripts/yazelix_setup.sh.' >&2
  exit 0
fi

"$nix_bin" profile add --refresh "$yazelix_ref"
printf 'Yazelix installed from %s. Run `yzx launch` when ready.\n' \
  "$yazelix_ref"

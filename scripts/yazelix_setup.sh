#!/usr/bin/env bash

set -euo pipefail

readonly yazelix_ref='github:Yazelix/nova/stable'
readonly nix_download_attempts=1

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

if "$nix_bin" --option download-attempts "$nix_download_attempts" \
    profile add --refresh "$yazelix_ref"; then
  :
else
  printf '%s\n' \
    'Yazelix installation failed; retrying once in case of a transient upstream build failure.' >&2
  if "$nix_bin" --option download-attempts "$nix_download_attempts" \
      profile add --refresh "$yazelix_ref"; then
    :
  else
    readonly install_status=$?
    printf '%s\n' \
      'Yazelix installation failed after two attempts.' \
      'If the log shows GitHub HTTP 429, wait for the rate limit to reset or configure Nix access-tokens, then rerun ./scripts/yazelix_setup.sh.' >&2
    exit "$install_status"
  fi
fi
printf 'Yazelix installed from %s. Run `yzx launch` when ready.\n' \
  "$yazelix_ref"

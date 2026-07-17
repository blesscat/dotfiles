#!/bin/bash

set -u

: "${CODEX_TEST_BOOTSTRAP_CAPTURE:?CODEX_TEST_BOOTSTRAP_CAPTURE is required}"

/usr/bin/printf 'STEP=nix\nEND\n' >> "$CODEX_TEST_BOOTSTRAP_CAPTURE"
nix_status="${CODEX_TEST_NIX_EXIT:-0}"
if [[ "${1:-}" == '--version' && "$nix_status" == '0' ]]; then
  /usr/bin/printf '%s\n' 'nix (Determinate Nix 3.8.1) 2.30.1'
fi
exit "$nix_status"

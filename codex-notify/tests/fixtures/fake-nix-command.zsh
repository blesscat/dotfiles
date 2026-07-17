#!/bin/zsh

set -u

: "${CIDER_TEST_NIX_CAPTURE:?CIDER_TEST_NIX_CAPTURE is required}"

/usr/bin/printf 'STEP=nix\n' >> "$CIDER_TEST_NIX_CAPTURE"
for argument in "$@"; do
  /usr/bin/printf 'ARG=%s\n' "$argument" >> "$CIDER_TEST_NIX_CAPTURE"
done
/usr/bin/printf 'END\n' >> "$CIDER_TEST_NIX_CAPTURE"

if [[ "${1:-}" == '--version' ]]; then
  (( ${CIDER_TEST_NIX_VERSION_EXIT:-0} == 0 && \
      ${CIDER_TEST_NIX_VERSION_EMPTY:-0} == 0 )) && \
    print 'nix (Determinate Nix 3.8.1) 2.30.1'
  exit "${CIDER_TEST_NIX_VERSION_EXIT:-0}"
fi
if [[ "${1:-}" == 'flake' && "${2:-}" == '--help' ]]; then
  exit "${CIDER_TEST_NIX_FLAKE_EXIT:-0}"
fi

exit 64

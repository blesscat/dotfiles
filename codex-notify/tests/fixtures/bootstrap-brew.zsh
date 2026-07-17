#!/bin/zsh

set -u

: "${CODEX_TEST_BOOTSTRAP_CAPTURE:?CODEX_TEST_BOOTSTRAP_CAPTURE is required}"

/usr/bin/printf 'STEP=brew\n' >> "$CODEX_TEST_BOOTSTRAP_CAPTURE"
/usr/bin/printf 'ARG=%s\n' "$@" >> "$CODEX_TEST_BOOTSTRAP_CAPTURE"
/usr/bin/printf 'END\n' >> "$CODEX_TEST_BOOTSTRAP_CAPTURE"

if [[ "${1-}" == 'shellenv' ]]; then
  /usr/bin/printf '%s\n' \
    'export CODEX_TEST_BREW_SHELLENV_APPLIED=1'
  exit 0
fi

if [[ "${1-}" == 'bundle' ]]; then
  if [[ "${CODEX_TEST_REQUIRE_SHELLENV:-0}" == '1' \
      && "${CODEX_TEST_BREW_SHELLENV_APPLIED:-0}" != '1' ]]; then
    exit 23
  fi
  exit "${CODEX_TEST_BUNDLE_EXIT:-0}"
fi

exit 0

#!/bin/zsh

set -u

: "${CODEX_TEST_BREW_PREFIX:?CODEX_TEST_BREW_PREFIX is required}"

if [[ -n "${CODEX_TEST_BREW_CAPTURE:-}" ]]; then
  /usr/bin/printf 'CALL\n' >> "$CODEX_TEST_BREW_CAPTURE"
  /usr/bin/printf 'ARG=%s\n' "$@" >> "$CODEX_TEST_BREW_CAPTURE"
fi

if (( $# == 2 )) && [[ "$1" == '--prefix' && "$2" == 'terminal-notifier' ]]; then
  /usr/bin/printf '%s\n' "$CODEX_TEST_BREW_PREFIX"
  exit "${CODEX_TEST_BREW_EXIT_CODE:-0}"
fi

exit 2

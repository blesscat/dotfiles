#!/bin/zsh

set -u

/usr/bin/printf 'STEP=installer\n' >> "$CODEX_TEST_BOOTSTRAP_CAPTURE"
if (( $# > 0 )); then
  /usr/bin/printf 'ARG=%s\n' "$@" >> "$CODEX_TEST_BOOTSTRAP_CAPTURE"
fi
/usr/bin/printf 'END\n' >> "$CODEX_TEST_BOOTSTRAP_CAPTURE"
exit "${CODEX_TEST_INSTALLER_EXIT:-0}"

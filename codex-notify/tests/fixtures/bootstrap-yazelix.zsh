#!/bin/zsh

set -u

: "${CODEX_TEST_BOOTSTRAP_CAPTURE:?CODEX_TEST_BOOTSTRAP_CAPTURE is required}"

/usr/bin/printf 'STEP=yazelix\n' >> "$CODEX_TEST_BOOTSTRAP_CAPTURE"
/usr/bin/printf 'END\n' >> "$CODEX_TEST_BOOTSTRAP_CAPTURE"
exit "${CODEX_TEST_YAZELIX_EXIT:-0}"

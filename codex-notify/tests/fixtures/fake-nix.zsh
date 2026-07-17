#!/bin/zsh

set -u

: "${YAZELIX_TEST_NIX_CAPTURE:?YAZELIX_TEST_NIX_CAPTURE is required}"
/usr/bin/printf '%s\n' "$@" > "$YAZELIX_TEST_NIX_CAPTURE"
exit "${YAZELIX_TEST_NIX_EXIT:-0}"

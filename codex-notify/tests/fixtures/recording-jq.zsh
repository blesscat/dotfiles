#!/bin/zsh

set -u

: "${CODEX_NOTIFY_TEST_REAL_JQ:?CODEX_NOTIFY_TEST_REAL_JQ is required}"
: "${CODEX_NOTIFY_TEST_JQ_CAPTURE:?CODEX_NOTIFY_TEST_JQ_CAPTURE is required}"

/usr/bin/printf '%s\n' "$@" >> "$CODEX_NOTIFY_TEST_JQ_CAPTURE"
exec "$CODEX_NOTIFY_TEST_REAL_JQ" "$@"

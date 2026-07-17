#!/bin/zsh

set -u

: "${CODEX_ROUTE_OPEN_CAPTURE_FILE:?CODEX_ROUTE_OPEN_CAPTURE_FILE is required}"

/usr/bin/printf '%s\n' "$@" > "$CODEX_ROUTE_OPEN_CAPTURE_FILE"

exit "${CODEX_ROUTE_OPEN_EXIT_CODE:-0}"


#!/bin/zsh

set -u

: "${CODEX_ROUTE_ZELLIJ_CAPTURE_FILE:?CODEX_ROUTE_ZELLIJ_CAPTURE_FILE is required}"

/usr/bin/printf '%s\n' "$@" > "$CODEX_ROUTE_ZELLIJ_CAPTURE_FILE"

if [[ -n "${CODEX_ROUTE_ZELLIJ_STDERR:-}" ]]; then
  /usr/bin/printf '%s\n' "$CODEX_ROUTE_ZELLIJ_STDERR" >&2
fi

exit "${CODEX_ROUTE_ZELLIJ_EXIT_CODE:-0}"

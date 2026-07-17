#!/bin/zsh

set -u

: "${CODEX_NOTIFY_CAPTURE_FILE:?CODEX_NOTIFY_CAPTURE_FILE is required}"

/usr/bin/printf '%s\n' "$@" > "$CODEX_NOTIFY_CAPTURE_FILE"

if [[ -n "${CODEX_NOTIFY_PID_FILE:-}" ]]; then
  /usr/bin/printf '%s\n' "$$" > "$CODEX_NOTIFY_PID_FILE"
fi

/bin/sleep "${CODEX_NOTIFY_HOLD_SECONDS:-0}"

if [[ -n "${CODEX_NOTIFY_DONE_FILE:-}" ]]; then
  /usr/bin/printf 'done\n' > "$CODEX_NOTIFY_DONE_FILE"
fi

exit "${CODEX_NOTIFY_EXIT_CODE:-0}"

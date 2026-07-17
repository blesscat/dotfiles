#!/bin/zsh

set -u

if [[ -n "${CODEX_ROUTE_OSASCRIPT_CAPTURE_FILE:-}" ]]; then
  /usr/bin/printf '%s\n' "$@" >> "$CODEX_ROUTE_OSASCRIPT_CAPTURE_FILE"
fi

/bin/cat >/dev/null

exit_code="${CODEX_ROUTE_OSASCRIPT_EXIT_CODE:-0}"
if (( exit_code != 0 )); then
  exit "$exit_code"
fi

if (( $# == 2 )); then
  /usr/bin/printf '%s\n' \
    "${CODEX_ROUTE_TERMINAL_ID:-04E67EB2-B11F-4C47-94CC-ED1550FA0978}"
else
  /usr/bin/printf '%s\n' "${CODEX_ROUTE_FOCUS_RESULT:-id}"
fi


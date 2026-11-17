#!/bin/sh
# Prints OpenCode's token stats for today and the last 7 days as one JSON line and exits:
#   {"today":<opencode stats --days 0 --json>,"week":<opencode stats --days 7 --json>}
#
# Prefer the local read-only DB adapters, which work with both legacy and current
# OpenCode even when a desktop app's PATH cannot find an NVM-installed CLI.
# With no database (or an explicit binary override), use the CLI below.
# --days 0 is today since local midnight. --days 7 is today and the six days before:
# on opencode 2.2.5 its range.from is local midnight six days back (checked against
# --days 0 and --days 6, which starts one day later), so N counts today.
# Adding the tokens up is providers/opencode.js's job.
#
# Exit: 0 = printed, 127 = opencode CLI not found, 1 = a call failed, printed no JSON
# object, or didn't finish within 10 s (TERM, then KILL a second later).
# Override the binary with HERDR_USAGE_OPENCODE_BIN.

db=${HERDR_USAGE_OPENCODE_DB:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db}
if [ -z "${HERDR_USAGE_OPENCODE_BIN:-}" ] && [ -f "$db" ]; then
  exec sh "$(dirname "$0")/opencode-spend-db.sh" "$db"
fi
OC=$(command -v "${HERDR_USAGE_OPENCODE_BIN:-opencode}" 2>/dev/null) || exit 127

dir=$(mktemp -d "${TMPDIR:-/tmp}/herdr-opencode-spend.XXXXXX") || exit 1
trap 'rm -rf "$dir"' EXIT

# Both calls run at once, stdin closed, under one deadline.
"$OC" stats --days 0 --json </dev/null >"$dir/today" 2>/dev/null &
p1=$!
"$OC" stats --days 7 --json </dev/null >"$dir/week" 2>/dev/null &
p2=$!

i=0
while kill -0 "$p1" 2>/dev/null || kill -0 "$p2" 2>/dev/null; do
  if [ "$i" -ge 50 ]; then
    kill "$p1" "$p2" 2>/dev/null
    # A CLI that ignores TERM gets about a second, then KILL; only then wait.
    j=0
    while [ "$j" -lt 5 ] && { kill -0 "$p1" 2>/dev/null || kill -0 "$p2" 2>/dev/null; }; do
      sleep 0.2
      j=$((j + 1))
    done
    kill -9 "$p1" "$p2" 2>/dev/null
    wait "$p1" "$p2" 2>/dev/null
    exit 1
  fi
  sleep 0.2
  i=$((i + 1))
done
wait "$p1" || exit 1
wait "$p2" || exit 1

# A notice the CLI prints first (an update, a warning) is cut off: each reply starts at
# its first line that starts with {. The CLI pretty-prints over many lines; JSON strings
# hold no raw newlines, so joining the lines keeps the object intact.
today=$(sed -n '/^{/,$p' "$dir/today" | tr -d '\r\n')
week=$(sed -n '/^{/,$p' "$dir/week" | tr -d '\r\n')
for v in "$today" "$week"; do
  v=${v#"${v%%[![:space:]]*}"}
  v=${v%"${v##*[![:space:]]}"}
  case "$v" in
    "{"*"}") ;;
    *) exit 1 ;;
  esac
done
printf '{"today":%s,"week":%s}\n' "$today" "$week"


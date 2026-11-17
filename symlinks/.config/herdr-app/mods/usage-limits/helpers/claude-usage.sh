#!/bin/sh
# Prints Claude Code's usage (one `control_response` JSON line) and exits.
#
# Runs your own `claude` CLI briefly and sends it the `get_usage` control
# request; the CLI authenticates itself. This script reads no tokens or
# credential files, sends no prompt and starts no turn. `--safe-mode` keeps
# hooks, MCP servers and customizations out of it.
# Approach credit: jmalicki/herdr-mod-ai-usage (MIT).
#
# Exit: 0 = printed the reply, 127 = claude CLI not found, 1 = no reply in 15 s.
# Override the binary with HERDR_USAGE_CLAUDE_BIN.

CLAUDE=$(command -v "${HERDR_USAGE_CLAUDE_BIN:-claude}" 2>/dev/null) || exit 127

dir=$(mktemp -d "${TMPDIR:-/tmp}/herdr-claude-usage.XXXXXX") || exit 1
out="$dir/out"

# The request comes from a regular file, not a FIFO: on Windows (Git sh) a native
# claude.exe never answers through mkfifo. The CLI still answers a control request
# it read before reaching end of input. A file rather than a pipe keeps $! the
# CLI's own pid in every sh, so the kill below reaches it.
printf '%s\n' '{"type":"control_request","request_id":"herdr-usage-limits","request":{"subtype":"get_usage","skip_behaviors":true}}' >"$dir/in"
"$CLAUDE" -p --safe-mode --no-session-persistence \
  --input-format stream-json --output-format stream-json --verbose \
  <"$dir/in" >"$out" 2>/dev/null &
pid=$!

i=0
while [ "$i" -lt 75 ]; do
  if grep -q '"control_response"' "$out" 2>/dev/null; then break; fi
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.2
  i=$((i + 1))
done
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null

status=1
if grep -m1 '"control_response"' "$out"; then status=0; fi
rm -rf "$dir"
exit $status


#!/bin/sh
# Prints Codex's rate limits as one JSON line and exits.
#
# Asks `codex app-server` (JSON-RPC: initialize, initialized,
# account/rateLimits/read); Codex authenticates itself and this script reads no
# tokens. If that fails, prints the newest rate-limit snapshot Codex logged in
# its sessions (last 14 days) as {"snapshot": <line>}.
#
# Exit: 0 = printed something, 127 = codex CLI not found,
# 1 = codex found but no reply and no snapshot.
# Override the binary with HERDR_USAGE_CODEX_BIN; sessions follow CODEX_HOME.

# Not installed: say so, even if old session logs exist (they'd look like a reading).
CODEX=$(command -v "${HERDR_USAGE_CODEX_BIN:-codex}" 2>/dev/null) || exit 127

{
  dir=$(mktemp -d "${TMPDIR:-/tmp}/herdr-codex-limits.XXXXXX") || exit 1
  out="$dir/out"
  : >"$out"
  # A clock, not a count: Git Bash forks slowly, and 75 rounds of 0.2 s ran to 20 s there.
  end=$(($(date +%s) + 15))

  # The requests go in through a pipe that stays open until the answer is out
  # (at most 15 s): app-server quits at end of input without answering, and
  # once it has answered, end of input lets it exit by itself.
  # A pipe, not a FIFO: with Git Bash on Windows, a FIFO reaches codex empty.
  # The writer holds none of this script's output, so it can't keep a caller waiting.
  {
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"herdr-usage-limits","version":"1.0"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","method":"initialized"}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read","params":{}}'
    while [ "$(date +%s)" -lt "$end" ] && [ -f "$out" ] && ! grep -q '"id":2' "$out"; do
      sleep 0.2
    done
  } 2>/dev/null | "$CODEX" app-server >"$out" 2>/dev/null &
  pid=$!

  while [ "$(date +%s)" -lt "$end" ]; do
    if grep -q '"id":2' "$out" 2>/dev/null; then break; fi
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.2
  done
  # Answered: its input closes too, so it gets up to 2 s to exit by itself.
  if grep -q '"id":2' "$out" 2>/dev/null; then
    i=0
    while [ "$i" -lt 10 ] && kill -0 "$pid" 2>/dev/null; do
      sleep 0.2
      i=$((i + 1))
    done
  fi
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null

  if grep -m1 '"id":2' "$out"; then
    rm -rf "$dir"
    exit 0
  fi
  rm -rf "$dir"
}

# app-server didn't answer: offer the newest logged snapshot (the mod shows it
# as the last reading, dated, with the provider marked as failing).
sessions="${CODEX_HOME:-$HOME/.codex}/sessions"
if [ -d "$sessions" ]; then
  for f in $(find "$sessions" -name '*.jsonl' -mtime -14 2>/dev/null | xargs ls -t 2>/dev/null | head -30); do
    line=$(grep -h '"rate_limits":{' "$f" 2>/dev/null | tail -1)
    if [ -n "$line" ]; then
      printf '{"snapshot":%s}\n' "$line"
      exit 0
    fi
  done
fi

exit 1


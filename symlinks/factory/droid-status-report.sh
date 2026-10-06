#!/bin/sh
# Orca droid status reporter.
# Reads droid hook JSON on stdin and POSTs it to Orca's agent hook endpoint
# so Orca can update the terminal tab title, sidebar worktree name, and branch.
# Silent no-op outside Orca terminals or while Orca is down (fail-open).

payload=$(cat)

# Skip high-frequency tool events; Orca only needs lifecycle status.
case "$payload" in
  *'"PreToolUse"'*|*'"PostToolUse"'*|*'"PostToolUseFailure"'*) exit 0 ;;
esac

[ -n "${ORCA_PANE_KEY:-}" ] || exit 0

# Prefer the on-disk endpoint file: Orca rewrites it on every start, so a
# long-lived droid process picks up the current port/token instead of the
# env frozen at launch.
if [ -n "${ORCA_AGENT_HOOK_ENDPOINT:-}" ] && [ -r "$ORCA_AGENT_HOOK_ENDPOINT" ]; then
  . "$ORCA_AGENT_HOOK_ENDPOINT"
fi

[ -n "${ORCA_AGENT_HOOK_PORT:-}" ] || exit 0
[ -n "${ORCA_AGENT_HOOK_TOKEN:-}" ] || exit 0

printf '%s' "$payload" | curl -sS -X POST \
  "http://127.0.0.1:${ORCA_AGENT_HOOK_PORT}/hook/droid" \
  --connect-timeout 0.5 --max-time 1.5 \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "X-Orca-Agent-Hook-Token: ${ORCA_AGENT_HOOK_TOKEN}" \
  --data-urlencode "paneKey=${ORCA_PANE_KEY}" \
  --data-urlencode "tabId=${ORCA_TAB_ID:-}" \
  --data-urlencode "launchToken=${ORCA_AGENT_LAUNCH_TOKEN:-}" \
  --data-urlencode "worktreeId=${ORCA_WORKTREE_ID:-}" \
  --data-urlencode "env=${ORCA_AGENT_HOOK_ENV:-}" \
  --data-urlencode "version=${ORCA_AGENT_HOOK_VERSION:-}" \
  --data-urlencode "payload@-" >/dev/null 2>&1 || :

exit 0

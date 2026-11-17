#!/bin/sh
# Prints one line per Pi assistant reply in the session files written in the last
# 8 days, oldest first, and exits:
#   <ISO timestamp> <totalTokens>
#
# Pi has no stats command; its session files hold the whole conversation. Only the
# reply's timestamp and token count leave this script, never message text. Text in them
# is JSON-escaped, so \"role\" can't match the "role" looked for here. The files are
# read, Pi itself is never run. Adding the numbers up by day is providers/pi.js's job.
#
# Sessions: ${HERDR_USAGE_PI_HOME:-$HOME/.pi}/agent/sessions/<folder>/<start>_<id>.jsonl
# Exit: 0 = printed (nothing when there are no replies), 127 = no sessions folder (Pi not
# installed), 1 = the sessions folder itself can't be read. A folder or file in it that
# can't be read is left out; the others are still counted.

dir=${HERDR_USAGE_PI_HOME:-$HOME/.pi}/agent/sessions
[ -d "$dir" ] || exit 127

# A message line: {"type":"message",...,"timestamp":"<ISO>","message":{"role":...}}.
# The line's own timestamp comes before "message":{ (the reply has a numeric one of its
# own inside, and a tool call's arguments can hold anything). The first "role" is the
# message's. The reply's "usage" is one of the message's own fields, after its content: the
# last "usage" counts only if, from it to the end, the line closes exactly the message and
# itself (strings dropped first); inside a tool call's arguments it closes more, and a ]
# among them, and the reply adds no line. Without totalTokens, its parts are added up.
prog='
  function num(s, k,   p) {
    p = "\"" k "\":[0-9]+"
    if (!match(s, p)) return 0
    return substr(s, RSTART + length(k) + 3, RLENGTH - length(k) - 3) + 0
  }
  function last(s, k,   i, j) {
    j = 0
    while ((i = index(s, k)) > 0) { j += i; s = substr(s, i + 1) }
    return j
  }
  function own(s, k,   i, t) {
    i = last(s, k)
    if (!i) return 0
    t = substr(s, i + length(k) - 1)
    gsub(/\\./, "", t); gsub(/"[^"]*"/, "", t); gsub(/[^][{}]/, "", t)
    while (gsub(/[{][}]|[[][]]/, "", t)) ;
    return t == "}}" ? i : 0
  }
  /^\{"type":"message"/ {
    m = index($0, "\"message\":{\"role\":\"")
    if (!m) next
    r = substr($0, m + 19); r = substr(r, 1, index(r, "\"") - 1)
    if (r != "assistant") next
    t = index($0, "\"timestamp\":\"")
    if (!t || t > m) next
    ts = substr($0, t + 13); ts = substr(ts, 1, index(ts, "\"") - 1)
    if (ts !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9](\.[0-9]+)?Z$/) next
    u = own($0, "\"usage\":{")
    if (!u) next
    s = substr($0, u)
    n = num(s, "totalTokens")
    if (n <= 0) n = num(s, "input") + num(s, "output") + num(s, "cacheRead") + num(s, "cacheWrite")
    if (n > 0) printf "%s %d\n", ts, n
  }'

[ -r "$dir" ] && [ -x "$dir" ] || exit 1
# The trailing / makes find enter the folder when it is a symlink. find's own status is
# not used: one folder it can't enter would lose them all. Only readable files go to awk,
# which would stop at the first it can't open.
out=$(find "$dir/" -type f -name '*.jsonl' -mtime -8 -exec sh -c '
  p=$1; shift
  for f; do shift; [ -r "$f" ] && set -- "$@" "$f"; done
  [ $# -eq 0 ] || awk "$p" "$@"' sh "$prog" {} + 2>/dev/null)
[ -n "$out" ] || exit 0
# ISO timestamps in UTC sort as text.
printf '%s\n' "$out" | LC_ALL=C sort


#!/bin/sh
# Prints one line of numbers about the session a process is running, and exits:
#   claude:   tokens=N calls=N compactions=N [lastTrigger=auto lastPre=N lastPost=N]
#   codex:    tokens=N window=N calls=N compactions=N (needs python3)
#   opencode: tokens=N calls=N compactions=N [model=<id>]
#   pi:       tokens=N calls=N [model=<id>]
#
# Usage: session.sh claude|codex|opencode|pi <pid of the agent in the terminal>
#
# Session files hold the whole conversation. Only numbers leave this script,
# except Codex's unbound session picker (IDs and titles, never message bodies).
# Text in them is JSON-escaped, so \"type\" can't match the "type" looked for here.
# Calls are the person's messages: Claude's "last-prompt" marker repeats within a turn.
#
# Exit: 0 = printed, 1 = no reading. Codex: 2 = JSON choices requiring an explicit selection.
# Codex accepts optional thread ID and process identity, supplied by the mod after selection.
# Claude's files follow CLAUDE_CONFIG_DIR, then %USERPROFILE%\.claude, then ~/.claude.
# Pi's follow HERDR_USAGE_PI_HOME, then ~/.pi. A model id leaves only if it is [A-Za-z0-9._:/-]+.
# OpenCode's database: HERDR_USAGE_OPENCODE_DB, then $XDG_DATA_HOME or ~/.local/share
# /opencode/opencode.db, read with HERDR_USAGE_SQLITE_BIN or sqlite3 (none: exit 1).
# Tests replace what is looked up about the process: HERDR_USAGE_PROC_CWD, HERDR_USAGE_PROC_START
# (epoch s) and HERDR_USAGE_PROC_PEERS (agents of that name in that directory, itself included).

app=$1
pid=$2
case "$pid" in '' | *[!0-9]*) exit 1 ;; esac

# The number after "key": in a line, 0 if there is none.
NUM='function num(s, k,   p) {
  p = "\"" k "\":[0-9]+"
  if (!match(s, p)) return 0
  return substr(s, RSTART + length(k) + 3, RLENGTH - length(k) - 3) + 0
}'

# The position of the last "key":<value> on a Pi message line, if it is one of the
# message's own fields: from its value to the end, the line then closes exactly two
# objects, the message and the line ({"type":"message",...,"message":{...}}). Inside the
# content (a tool call's arguments, say) it closes more, and a ] among them: 0.
# Strings go first (their escapes, then themselves), so no text inside them counts.
OWN='
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
}'

claude() {
  # On Windows, Git sh's $HOME can be a network drive while Claude Code keeps
  # its files under %USERPROFILE%, so that wins when it has a .claude folder.
  claude_home=$HOME
  if [ -n "$USERPROFILE" ]; then
    up=$(cygpath -u "$USERPROFILE" 2>/dev/null || printf '%s' "$USERPROFILE")
    [ -d "$up/.claude" ] && claude_home=$up
  fi
  dir=${CLAUDE_CONFIG_DIR:-$claude_home/.claude}
  [ -f "$dir/sessions/$pid.json" ] || exit 1
  id=$(sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p' "$dir/sessions/$pid.json")
  case "$id" in '' | *[!0-9a-zA-Z-]*) exit 1 ;; esac
  for file in "$dir"/projects/*/"$id".jsonl; do
    [ -f "$file" ] || exit 1
    awk "$NUM"'
      /"type":"user"/ && /"isSidechain":false/ && !/"isMeta":true/ && !/"isCompactSummary":true/ && !/"type":"tool_result"/ { calls++ }
      /"subtype":"compact_boundary"/ {
        compactions++
        pre = num($0, "preTokens"); post = num($0, "postTokens"); tokens = post
        trigger = match($0, /"trigger":"[a-z]+"/) ? substr($0, RSTART + 11, RLENGTH - 12) : ""
      }
      /"type":"assistant"/ && /"isSidechain":false/ {
        u = index($0, "\"usage\":{")
        if (u) {
          s = substr($0, u)
          # With server tools, usage adds up every request of the turn: the last one is the context.
          i = index(s, "\"iterations\":[")
          if (i) {
            t = substr(s, i)
            while ((i = index(t, "{\"input_tokens\":")) > 0) { s = substr(t, i); t = substr(t, i + 1) }
          }
          n = num(s, "input_tokens") + num(s, "cache_creation_input_tokens") + num(s, "cache_read_input_tokens")
          if (n > 0) tokens = n
        }
      }
      END {
        if (!tokens) exit 1
        printf "tokens=%d calls=%d compactions=%d", tokens, calls, compactions
        if (compactions) printf " lastTrigger=%s lastPre=%d lastPost=%d", trigger, pre, post
        printf "\n"
      }' "$file"
    exit $?
  done
}

# ---- Agents that hold no session file open: the process is tied to its session
# by its working directory and its start time. ----

# lsof -Fn's name as a printf format: lsof writes a byte it won't print as \xNN (any
# non-ASCII byte under the C locale) and a backslash as \\; these turn into \ooo and \\,
# and % into %%. Any other escape (a control character) can't be undone: nothing.
UNESCAPE='BEGIN { X = "0123456789abcdef" }
  function pct(x) { gsub(/%/, "%%", x); return x }
  NR == 1 {
    s = $0; out = ""
    while ((i = index(s, "\\")) > 0) {
      out = out pct(substr(s, 1, i - 1)); c = substr(s, i + 1, 1); h = tolower(substr(s, i + 2, 2))
      if (c == "\\") { out = out "\\\\"; s = substr(s, i + 2) }
      else if (c == "x" && h ~ /^[0-9a-f][0-9a-f]$/) {
        out = out sprintf("\\%03o", 16 * (index(X, substr(h, 1, 1)) - 1) + index(X, substr(h, 2, 1)) - 1)
        s = substr(s, i + 4)
      } else exit 1
    }
    printf "%s", out pct(s)
  }'

# The process's working directory, whatever the locale: /proc where there is one, else
# lsof under the C locale with its escapes undone.
proc_cwd() {
  d=$(readlink "/proc/$1/cwd" 2>/dev/null)
  if [ -z "$d" ]; then
    f=$(LC_ALL=C lsof -w -a -d cwd -p "$1" -Fn 2>/dev/null | sed -n 's/^n//p' | awk "$UNESCAPE") || f=
    case "$f" in /*) d=$(printf "$f") ;; esac
  fi
  printf '%s' "$d"
}

# Now minus the elapsed time, [[dd-]hh:]mm:ss on macOS and Linux alike.
proc_start() {
  ps -o etime= -p "$1" 2>/dev/null | awk -v now="$(date +%s)" '
    NF {
      e = $1; d = 0
      if (i = index(e, "-")) { d = substr(e, 1, i - 1); e = substr(e, i + 1) }
      n = split(e, p, ":"); s = 0
      for (k = 1; k <= n; k++) s = s * 60 + p[k]
      print now - (d * 86400 + s)
    }'
}

# Processes with the command name of $1 whose working directory is $2, $1 included.
# By name, not arguments: "pi" and "pi --model x" in one folder are still two. The name's
# last part only: macOS gives the full path when a program was started by its path.
# $3, if given, is a word: a process whose first argument after the command is that word
# isn't counted (OpenCode's background "opencode serve --service" is no terminal client).
proc_peers() {
  name=$(ps -o comm= -p "$1" 2>/dev/null)
  [ -n "$name" ] || return
  name=${name##*/}
  n=0
  for p in $(ps -A -o pid=,comm= 2>/dev/null | awk -v c="$name" '{ pid = $1; sub(/^ *[0-9]+ /, ""); sub(/.*\//, ""); if ($0 == c) print pid }'); do
    if [ -n "$3" ]; then
      ps -o args= -p "$p" 2>/dev/null | awk -v w="$3" '{ exit !($2 == w) }' && continue
    fi
    [ "$(proc_cwd "$p")" = "$2" ] && n=$((n + 1))
  done
  printf '%s' "$n"
}

mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }

pi() {
  cwd=${HERDR_USAGE_PROC_CWD:-$(proc_cwd "$pid")}
  start=${HERDR_USAGE_PROC_START:-$(proc_start "$pid")}
  peers=${HERDR_USAGE_PROC_PEERS:-$(proc_peers "$pid" "$cwd")}
  case "$cwd" in /*) ;; *) exit 1 ;; esac
  case "$start" in '' | *[!0-9]*) exit 1 ;; esac
  case "$peers" in '' | *[!0-9]* | 0) exit 1 ;; esac
  # Pi's folder: the directory without its leading /, each / \ : as -, wrapped in --.
  dir=${HERDR_USAGE_PI_HOME:-$HOME/.pi}/agent/sessions/--$(printf '%s' "${cwd#/}" | tr '/\\:' '---')--
  [ -d "$dir" ] || exit 1
  # Candidates: started or written since the process started. Its own session started
  # within 2 s of it (the file name's timestamp is when Pi started). With several such
  # processes in the folder, only that one counts. With one, that one too, unless another
  # candidate was written after it (another Pi came and went); and if none started then,
  # the only candidate, if it started before the process (a resumed session: one that
  # started later is another Pi's, which came and went). Anything else: nothing.
  file=$(for f in "$dir"/*.jsonl; do
    [ -f "$f" ] && printf '%s %s\n' "$(mtime "$f")" "$f"
  done | awk -v start="$start" -v peers="$peers" '
    function days(y, m, d) { # days since 1970-01-01 of a Gregorian date
      if (m <= 2) { y--; m += 12 }
      return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + d - 719469
    }
    {
      m = $1; f = substr($0, index($0, " ") + 1); b = f; sub(/.*\//, "", b)
      t = -1
      if (b ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)
        t = days(substr(b, 1, 4) + 0, substr(b, 6, 2) + 0, substr(b, 9, 2) + 0) * 86400 + substr(b, 12, 2) * 3600 + substr(b, 15, 2) * 60 + substr(b, 18, 2)
      if (t < start - 2 && m < start) next
      n++; any = f; at = t
      if (t >= start - 2 && t <= start + 2) { own = f; om = m; hits++ }
      else if (m > other) other = m
    }
    END {
      if (hits == 1 && (peers > 1 || other <= om)) print own
      else if (!hits && peers == 1 && n == 1 && at >= 0 && at < start) print any
    }')
  [ -n "$file" ] || exit 1
  # A message's role comes before its content, so the first "role" on a line is the
  # message's. The reply's own "model" and "usage" are among the message's own fields, which
  # follow its content; a reply without one of its own must not take one from a tool call's
  # arguments, so a key counts only at the message's own level (see OWN).
  # Compactions aren't counted: none could be made to happen to see how they are written.
  # Pi 1.5.0's source writes a {"type":"compaction"} line; after one, the last reply's
  # context is from before it, so it is dropped until the next reply (Pi's footer too).
  awk "$NUM$OWN"'
    function role(s,   i) {
      i = index(s, "\"message\":{\"role\":\"")
      if (!i) return ""
      s = substr(s, i + 19)
      return substr(s, 1, index(s, "\"") - 1)
    }
    /^\{"type":"compaction"/ { tokens = 0; model = "" }
    /^\{"type":"message"/ {
      r = role($0)
      if (r == "user") calls++
      if (r != "assistant") next
      u = own($0, "\"usage\":{")
      if (!u) next
      s = substr($0, u)
      n = num(s, "input") + num(s, "cacheRead") + num(s, "cacheWrite")
      if (n <= 0) next
      tokens = n; model = ""
      i = own($0, "\"model\":\"")
      if (i) {
        s = substr($0, i + 9); s = substr(s, 1, index(s, "\"") - 1)
        if (s ~ /^[A-Za-z0-9._:\/-]+$/) model = s
      }
    }
    END {
      if (!tokens) exit 1
      printf "tokens=%d calls=%d", tokens, calls
      if (model != "") printf " model=%s", model
      printf "\n"
    }' "$file"
}

# OpenCode keeps sessions in SQLite, written as it goes (WAL), read here read-only.
# Candidates: top-level sessions (not a subagent's) of the process's directory updated
# since it started. Shown only with one terminal client there and exactly one candidate.
# Once this client has written its own row, another writer in the folder (a client that
# came and went, an `opencode run`, the desktop or web app through the service), or /new
# here, makes two, and nothing is shown.
# Known, accepted risk: nothing ties a terminal client to its session (the service
# serves every client, and neither it nor Herdr reports which session a TUI shows). So
# while this client has sent nothing since it started (fresh, or `opencode -c` on an old
# session), a session another short-lived writer wrote in this folder meanwhile is the
# only candidate and is shown here. It turns into "nothing" at this client's first
# message, when its own row makes two.
opencode() {
  cwd=${HERDR_USAGE_PROC_CWD:-$(proc_cwd "$pid")}
  start=${HERDR_USAGE_PROC_START:-$(proc_start "$pid")}
  peers=${HERDR_USAGE_PROC_PEERS:-$(proc_peers "$pid" "$cwd" serve)}
  case "$cwd" in /*) ;; *) exit 1 ;; esac
  case "$start" in '' | *[!0-9]*) exit 1 ;; esac
  [ "$peers" = 1 ] || exit 1
  db=${HERDR_USAGE_OPENCODE_DB:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db}
  exec sh "$(dirname "$0")/opencode-session.sh" "$db" "$cwd" "$start"
}

case "$app" in
  claude) claude ;;
  codex) exec python3 -I "$(dirname "$0")/codex-session.py" "$pid" "${3:-}" "${4:-}" ;;
  opencode) opencode ;;
  pi) pi ;;
  *) exit 1 ;;
esac


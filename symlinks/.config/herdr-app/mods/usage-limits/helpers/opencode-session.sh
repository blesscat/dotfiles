#!/bin/sh
# Adapter dispatcher. Inputs: database, verified process directory and start epoch (s).
# Output is the same numeric session contract for every supported OpenCode schema.
db=$1
cwd=$2
start=$3
case "$cwd" in /*) ;; *) exit 1 ;; esac
case "$start" in '' | *[!0-9]*) exit 1 ;; esac
bin=${HERDR_USAGE_SQLITE_BIN:-sqlite3}
command -v "$bin" >/dev/null 2>&1 || exit 1
[ -f "$db" ] || exit 1
dir=$(dirname "$0")/opencode
tables=$("$bin" -readonly -batch -cmd '.timeout 2000' "$db" \
  "select ',' || group_concat(name, ',') || ',' from sqlite_master where type = 'table';" 2>/dev/null) || exit 1
views=
sessions=
messages=
case "$tables" in
  *,session,*) case "$tables" in
    *,message,*) case "$tables" in
      *,part,*)
        views=$(cat "$dir/legacy.sql") || exit 1
        sessions='select * from ul_sessions_v1'
        messages='select * from ul_messages_v1'
        ;;
    esac ;;
  esac ;;
esac
case "$tables" in
  *,session_v2,*) case "$tables" in
    *,session_message,*)
      views="$views
$(cat "$dir/current.sql")" || exit 1
      [ -z "$sessions" ] || sessions="$sessions union all "
      [ -z "$messages" ] || messages="$messages union all "
      sessions="${sessions}select * from ul_sessions_v2"
      messages="${messages}select * from ul_messages_v2"
      ;;
  esac ;;
esac
[ -n "$sessions" ] || exit 1
query=$(cat "$dir/session.sql") || exit 1
q=$(printf '%s' "$cwd" | sed "s/'/''/g")
# TEMP views exist only in this read-only connection. One snapshot covers both stores.
row=$("$bin" -readonly -batch -cmd '.timeout 2000' "$db" "begin;
  create temp view ul_target as select '$q' as directory, ${start}000 as since;
  $views
  create temp view ul_sessions as $sessions;
  create temp view ul_messages as $messages;
  $query
  commit;" </dev/null 2>/dev/null) || exit 1
IFS='|' read -r tokens calls compactions model <<EOF
$row
EOF
case "$tokens" in '' | *[!0-9]* | 0) exit 1 ;; esac
case "$calls" in '' | *[!0-9]*) exit 1 ;; esac
case "$compactions" in '' | *[!0-9]*) exit 1 ;; esac
case "$model" in '' | *[!A-Za-z0-9._:/-]*) model= ;; esac
printf 'tokens=%s calls=%s compactions=%s' "$tokens" "$calls" "$compactions"
[ -z "$model" ] || printf ' model=%s' "$model"
printf '\n'


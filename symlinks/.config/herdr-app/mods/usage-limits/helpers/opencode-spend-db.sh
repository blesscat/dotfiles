#!/bin/sh
# Local statistics for both schemas, independent of GUI PATH and CLI --json support.
# Only numeric JSON leaves this helper. No credentials or conversation text.
db=$1
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
    *,message,*)
      views=$(cat "$dir/legacy-spend.sql") || exit 1
      sessions='select * from ul_spend_sessions_v1'
      messages='select * from ul_spend_messages_v1'
      ;;
  esac ;;
esac
case "$tables" in
  *,session_v2,*) case "$tables" in
    *,session_message,*)
      views="$views
$(cat "$dir/current-spend.sql")" || exit 1
      [ -z "$sessions" ] || sessions="$sessions union all "
      [ -z "$messages" ] || messages="$messages union all "
      sessions="${sessions}select * from ul_spend_sessions_v2"
      messages="${messages}select * from ul_spend_messages_v2"
      ;;
  esac ;;
esac
[ -n "$sessions" ] || exit 1
query=$(cat "$dir/spend.sql") || exit 1
"$bin" -readonly -batch -cmd '.timeout 2000' "$db" "begin;
  create temp view ul_clock as select
    cast(strftime('%s', 'now') as integer) * 1000 + 999 as now_ms,
    cast(strftime('%s', 'now', 'localtime', 'start of day', 'utc') as integer) * 1000 as today_start,
    cast(strftime('%s', 'now', 'localtime', 'start of day', '-6 days', 'utc') as integer) * 1000 as week_start;
  $views
  create temp view ul_spend_sessions as $sessions;
  create temp view ul_spend_messages as $messages;
  $query
  commit;" </dev/null 2>/dev/null || exit 1


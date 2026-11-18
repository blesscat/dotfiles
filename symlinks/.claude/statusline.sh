#!/bin/bash
# Claude Code status line:
# dir | branch | model | ctx N% | 5h N% (↻HH:MM) · 7d N% (↻Ddd HH:MM)
# Uses macOS (BSD) `date -r <epoch>`; falls back to GNU `date -d @<epoch>`.

input=$(cat)

# ---- Save rate limits for the agent usage page (~/.cider/agent-usage) -------
# One file per session; the page merges them and keeps the newest window.
{
  read -r sid rl <<< "$(printf '%s' "$input" | jq -rc '[(.session_id // "unknown"), (.rate_limits // null | tojson)] | join(" ")' 2>/dev/null)"
  if [ -n "$rl" ] && [ "$rl" != "null" ] && [[ "$sid" =~ ^[A-Za-z0-9_-]+$ ]]; then
    d="$HOME/.cache/agent-usage/claude"; mkdir -p "$d"
    tmp=$(mktemp "$d/.tmp.XXXXXX") && printf '{"at":%s,"rate_limits":%s}\n' "$(date +%s)" "$rl" > "$tmp" && mv -f "$tmp" "$d/$sid.json"
  fi
} 2>/dev/null

j() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

fmt_time() { # $1 = epoch, $2 = format
  date -r "$1" "+$2" 2>/dev/null || date -d "@$1" "+$2" 2>/dev/null
}

cwd=$(j '.workspace.current_dir // .cwd // empty')
model=$(j '.model.display_name // empty')
ctx=$(j '.context_window.used_percentage // empty')
h5=$(j '.rate_limits.five_hour.used_percentage // empty')
h5r=$(j '.rate_limits.five_hour.resets_at // empty')
d7=$(j '.rate_limits.seven_day.used_percentage // empty')
d7r=$(j '.rate_limits.seven_day.resets_at // empty')

B=$'\e[38;5;111m'; M=$'\e[38;5;183m'; D=$'\e[90m'; R0=$'\e[0m'
GRN=$'\e[38;5;114m'; YEL=$'\e[38;5;221m'; RED=$'\e[38;5;211m'
left() { # $1 = used% -> colored remaining%
  local r=$(( 100 - $(printf '%.0f' "$1") )); local c=$GRN
  [ "$r" -le 50 ] && c=$YEL; [ "$r" -le 20 ] && c=$RED
  printf '%s%s%%%s' "$c" "$r" "$R0"
}
segs=()

[ -n "$cwd" ] && segs+=("${B}$(basename "$cwd")${R0}")

if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null \
    || GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && segs+=("${M}${branch}${R0}")
fi

[ -n "$model" ] && segs+=("$model")

[ -n "$ctx" ] && segs+=("ctx $(printf '%.0f' "$ctx")%")

limits=""
if [ -n "$h5" ]; then
  limits="5h $(left "$h5")"
  if [ -n "$h5r" ]; then
    t=$(fmt_time "$h5r" "%H:%M")
    [ -n "$t" ] && limits="$limits (↻$t)"
  fi
fi
if [ -n "$d7" ]; then
  p="7d $(left "$d7")"
  if [ -n "$d7r" ]; then
    t=$(fmt_time "$d7r" "%a %H:%M")
    [ -n "$t" ] && p="$p (↻$t)"
  fi
  if [ -n "$limits" ]; then limits="$limits ${D}·${R0} $p"; else limits="$p"; fi
fi
[ -n "$limits" ] && segs+=("$limits")

out=""
for s in "${segs[@]}"; do
  if [ -z "$out" ]; then out="$s"; else out="$out ${D}|${R0} $s"; fi
done
printf '%s\n' "$out"

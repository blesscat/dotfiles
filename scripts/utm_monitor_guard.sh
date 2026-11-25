#!/usr/bin/env bash
# Keeps ~/.config/hypr/monitors.lua usable for omarchy-spice-guest-tools in a
# UTM VM. Run by utm-monitor-guard.path (installed by omarchy-utm.sh) whenever
# the file changes.
#
# Omarchy's display scaling (omarchy-hyprland-monitor-scaling) persists its
# scale as a per-output rule, e.g.
#   hl.monitor({ output = "Virtual-1", mode = "preferred", ..., scale = 1 })
# spice-guest-tools reinserts its managed block right after the first monitor
# rule at every login, so that rule ends up after the block and its
# mode = "preferred" resets the display to 1280x800 on every Hyprland reload.
#
# This removes per-output rules outside the managed block and carries the last
# one's plain numeric scale over to omarchy_monitor_scale, which the managed
# block uses, so the scaling shortcut keeps working.

set -euo pipefail

file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitors.lua"
[[ -f "$file" ]] || exit 0
grep -Fq -- '-- BEGIN spice-guest-tools managed mode' "$file" || exit 0

target="$(readlink -f "$file")"
tmp="$(mktemp "$target.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

awk '
  $0 == "-- BEGIN spice-guest-tools managed mode" { managed = 1 }
  !managed && /^[[:space:]]*hl\.monitor\(\{ *output *= *"[^"]+"/ {
    if (match($0, /scale *= *[0-9]+(\.[0-9]+)?/)) {
      scale = substr($0, RSTART, RLENGTH)
      sub(/^scale *= */, "", scale)
    }
    removed = 1
    next
  }
  { lines[++n] = $0 }
  $0 == "-- END spice-guest-tools managed mode" { managed = 0 }
  END {
    if (!removed) exit 3
    for (i = 1; i <= n; i++) {
      if (scale != "" && lines[i] ~ /^local omarchy_monitor_scale = /)
        lines[i] = "local omarchy_monitor_scale = " scale
      print lines[i]
    }
  }
' "$target" > "$tmp" && status=0 || status=$?

case "$status" in
  0) ;;
  3) exit 0 ;;  # nothing to remove
  *) exit "$status" ;;
esac

chmod --reference="$target" "$tmp"
mv -f "$tmp" "$target"
trap - EXIT
echo "removed per-output monitor rule from $target"
hyprctl reload >/dev/null 2>&1 || true

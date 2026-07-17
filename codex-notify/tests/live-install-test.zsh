#!/bin/zsh

set -u
unsetopt BG_NICE

readonly test_dir="${0:A:h}"
readonly module_dir="${CODEX_NOTIFY_TEST_MODULE_DIR:-${test_dir:h}}"
readonly installed_root="${CODEX_NOTIFY_TEST_INSTALLED_ROOT:-${HOME}/.local}"
readonly codesign_bin="${CODEX_NOTIFY_TEST_CODESIGN:-${commands[codesign]-}}"
readonly app="$installed_root/share/codex-notify/terminal-notifier.app"
readonly notifier="$app/Contents/MacOS/terminal-notifier"
readonly -a runtime_names=(
  codex-notify
  codex-permission-notify
  codex-notification-route
)

typeset -i failures=0

for runtime_name in "$runtime_names[@]"; do
  source="$module_dir/bin/$runtime_name"
  target="$installed_root/bin/$runtime_name"
  linked=''
  if [[ -L "$target" ]]; then
    linked="$(/usr/bin/readlink "$target" 2>/dev/null)"
  fi
  if [[ "$linked" != "$source" || ! -x "$target" ]]; then
    print -u2 -- "FAIL: live $runtime_name does not link to $source"
    (( failures += 1 ))
  fi
done

if [[ ! -x "$notifier" ]]; then
  print -u2 -- "FAIL: live Terminal Notifier helper is unavailable: $notifier"
  (( failures += 1 ))
elif [[ -z "$codesign_bin" || ! -x "$codesign_bin" ]]; then
  print -u2 'FAIL: codesign is unavailable'
  (( failures += 1 ))
elif ! "$codesign_bin" --verify --deep --strict "$app" 2>/dev/null; then
  print -u2 'FAIL: live Terminal Notifier helper signature is invalid'
  (( failures += 1 ))
fi

if (( failures > 0 )); then
  print -u2 -- "FAIL: $failures live installation assertion(s) failed"
  exit 1
fi

print 'PASS: live notification installation assets'

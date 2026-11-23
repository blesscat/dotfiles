#!/bin/zsh

set -u
unsetopt BG_NICE

readonly test_dir="${0:A:h}"
readonly module_dir="${test_dir:h}"
readonly real_jq="${commands[jq]-}"
readonly recording_jq="$test_dir/fixtures/recording-jq.zsh"
readonly recording_notifier="$test_dir/fixtures/recording-notifier.zsh"

if [[ ! -x "$real_jq" ]]; then
  print -u2 'FAIL: jq is required to exercise portable path discovery'
  exit 1
fi

readonly tmp_dir="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$tmp_dir"' EXIT HUP INT TERM

readonly portable_home="$tmp_dir/home"
readonly portable_codex="$tmp_dir/codex-home"
readonly portable_prefix="$tmp_dir/non-default-prefix"
readonly portable_module="$tmp_dir/module with spaces"
readonly installed_bin="$portable_home/.local/bin"
readonly jq_capture="$tmp_dir/jq.args"

/bin/mkdir -p \
  "$installed_bin" \
  "$portable_codex" \
  "$portable_prefix/bin" \
  "$portable_module/bin"

/bin/cp "$module_dir/bin/codex-notify" "$portable_module/bin/codex-notify"
/bin/cp "$module_dir/bin/codex-permission-notify" \
  "$portable_module/bin/codex-permission-notify"
/bin/chmod 755 "$portable_module/bin/"*

/bin/ln -s "$portable_module/bin/codex-notify" "$installed_bin/codex-notify"
/bin/ln -s "$portable_module/bin/codex-permission-notify" \
  "$installed_bin/codex-permission-notify"
/bin/ln -s "$recording_jq" "$portable_prefix/bin/jq"

typeset -i failures=0

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "$actual" != "$expected" ]]; then
    print -u2 "FAIL: $label (expected '$expected', got '$actual')"
    (( failures += 1 ))
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    print -u2 "FAIL: $label (missing '$needle')"
    (( failures += 1 ))
  fi
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"

  if [[ ! -f "$file" ]] || ! /usr/bin/grep -Fq -- "$needle" "$file"; then
    print -u2 "FAIL: $label (missing '$needle' in '$file')"
    (( failures += 1 ))
  fi
}

assert_nonempty_file() {
  local file="$1"
  local label="$2"

  if [[ ! -s "$file" ]]; then
    print -u2 "FAIL: $label ('$file' is missing or empty)"
    (( failures += 1 ))
  fi
}

argument_after_flag() {
  local file="$1"
  local flag="$2"
  local previous=''
  local line

  while IFS= read -r line; do
    if [[ "$previous" == "$flag" ]]; then
      print -r -- "$line"
      return 0
    fi
    previous="$line"
  done < "$file"

  return 1
}

for executable in codex-notify codex-permission-notify; do
  if [[ ! -L "$installed_bin/$executable" || ! -x "$installed_bin/$executable" ]]; then
    print -u2 "FAIL: installed $executable symlink is not executable"
    (( failures += 1 ))
  fi
done

portable_payload='{"type":"agent-turn-complete","cwd":"/portable/project","last-assistant-message":"portable done"}'
completion_args="$tmp_dir/completion.args"
completion_output="$(
  /usr/bin/env \
    -u CODEX_NOTIFY_JQ \
    -u CODEX_NOTIFY_LOG_FILE \
    HOME="$portable_home" \
    CODEX_HOME="$portable_codex" \
    PATH="$portable_prefix/bin:/usr/bin:/bin" \
    CODEX_NOTIFY_TEST_REAL_JQ="$real_jq" \
    CODEX_NOTIFY_TEST_JQ_CAPTURE="$jq_capture" \
    CODEX_NOTIFY_SKY_CLIENT=/bin/echo \
    CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
    CODEX_NOTIFY_CAPTURE_FILE="$completion_args" \
    CODEX_NOTIFY_EXIT_CODE=1 \
      "$installed_bin/codex-notify" "$portable_payload"
)"
completion_status=$?

assert_equal 0 "$completion_status" \
  'completion through an installed symlink remains non-blocking'
assert_contains "$completion_output" "turn-ended $portable_payload" \
  'portable completion preserves the Sky payload'
assert_equal 'portable done' "$(argument_after_flag "$completion_args" '-message')" \
  'portable completion parses with jq discovered from PATH'
assert_equal 'com.mitchellh.ghostty' \
  "$(argument_after_flag "$completion_args" '-activate')" \
  'portable completion activates Ghostty on click'
assert_nonempty_file "$jq_capture" \
  'completion invokes jq from the non-default prefix'
assert_file_contains "$portable_codex/log/codex-notify.log" \
  'component=terminal-notifier exit=1' \
  'default logs follow custom CODEX_HOME'

permission_args="$tmp_dir/permission.args"
permission_stdout="$tmp_dir/permission.stdout"
: > "$jq_capture"
/usr/bin/printf '%s' \
  '{"hook_event_name":"PermissionRequest","cwd":"/portable/project","tool_name":"Bash","tool_input":{"command":"git status"}}' | \
  /usr/bin/env \
    -u CODEX_PERMISSION_NOTIFY_JQ \
    -u CODEX_PERMISSION_NOTIFY_WRAPPER \
    -u CODEX_NOTIFY_JQ \
    -u CODEX_NOTIFY_LOG_FILE \
    HOME="$portable_home" \
    CODEX_HOME="$portable_codex" \
    PATH="$portable_prefix/bin:/usr/bin:/bin" \
    CODEX_NOTIFY_TEST_REAL_JQ="$real_jq" \
    CODEX_NOTIFY_TEST_JQ_CAPTURE="$jq_capture" \
    CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
    CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
    CODEX_NOTIFY_CAPTURE_FILE="$permission_args" \
      "$installed_bin/codex-permission-notify" > "$permission_stdout"
permission_status=$?

assert_equal 0 "$permission_status" \
  'permission adapter through an installed symlink remains non-blocking'
assert_equal '' "$(/bin/cat "$permission_stdout")" \
  'portable permission adapter keeps hook stdout empty'
assert_equal '等待權限核准：git status' \
  "$(argument_after_flag "$permission_args" '-message')" \
  'portable permission adapter finds jq and its sibling wrapper'
assert_equal 'com.mitchellh.ghostty' \
  "$(argument_after_flag "$permission_args" '-activate')" \
  'portable permission adapter reaches the sibling wrapper'
assert_nonempty_file "$jq_capture" \
  'permission adapter invokes jq from the non-default prefix'

if (( failures > 0 )); then
  print -u2 "FAIL: $failures portable path assertion(s) failed"
  exit 1
fi

print 'PASS: portable notification runtime paths'

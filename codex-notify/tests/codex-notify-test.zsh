#!/bin/zsh

set -u
unsetopt BG_NICE

readonly test_dir="${0:A:h}"
readonly module_dir="${CODEX_NOTIFY_TEST_MODULE_DIR:-${test_dir:h}}"
readonly jq_bin="${CODEX_NOTIFY_TEST_JQ:-${commands[jq]-}}"
readonly wrapper="${CODEX_NOTIFY_TEST_WRAPPER:-$module_dir/bin/codex-notify}"
readonly permission_adapter="${CODEX_NOTIFY_TEST_PERMISSION_ADAPTER:-$module_dir/bin/codex-permission-notify}"
readonly route_helper="${CODEX_NOTIFY_TEST_ROUTE_HELPER:-$module_dir/bin/codex-notification-route}"
readonly recording_notifier="$test_dir/fixtures/recording-notifier.zsh"
readonly recording_osascript="$test_dir/fixtures/recording-osascript.zsh"
readonly recording_zellij="$test_dir/fixtures/recording-zellij.zsh"
readonly recording_open="$test_dir/fixtures/recording-open.zsh"

if [[ ! -x "$jq_bin" ]]; then
  print -u2 'FAIL: jq is missing or not executable'
  exit 1
fi

if [[ ! -x "$wrapper" ]]; then
  print -u2 'FAIL: wrapper is missing or not executable'
  exit 1
fi

if [[ ! -x "$recording_notifier" ]]; then
  print -u2 'FAIL: recording notifier fixture is missing or not executable'
  exit 1
fi

for route_fixture in "$recording_osascript" "$recording_zellij" "$recording_open"; do
  if [[ ! -x "$route_fixture" ]]; then
    print -u2 "FAIL: route recorder fixture is missing or not executable: $route_fixture"
    exit 1
  fi
done

readonly tmp_dir="$(/usr/bin/mktemp -d)"
readonly log_file="$tmp_dir/codex-notify.log"
trap '/bin/rm -rf "$tmp_dir"' EXIT HUP INT TERM

# Keep established cases independent from the caller's live Yazelix state.
export CODEX_NOTIFY_ROUTE_HELPER="$tmp_dir/disabled-route-helper"
unset TERM_PROGRAM ZELLIJ ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID

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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    print -u2 "FAIL: $label (unexpected '$needle')"
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

assert_file_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"

  if [[ -f "$file" ]] && /usr/bin/grep -Fq -- "$needle" "$file"; then
    print -u2 "FAIL: $label (unexpected '$needle' in '$file')"
    (( failures += 1 ))
  fi
}

wait_for_file_contains() {
  local file="$1"
  local needle="$2"
  local attempt

  for attempt in {1..50}; do
    if [[ -f "$file" ]] && /usr/bin/grep -Fq -- "$needle" "$file"; then
      return 0
    fi
    /bin/sleep 0.02
  done

  return 1
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

assert_default_sound() {
  local file="$1"
  local label="$2"

  assert_equal 'default' "$(argument_after_flag "$file" '-sound')" "$label"
}

hex_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    print -r -- ''
    return 0
  fi

  LC_ALL=C /usr/bin/od -An -tx1 "$file" | /usr/bin/tr -d '[:space:]'
}

run_message_case() {
  local case_name="$1"
  local case_payload="$2"
  local expected_message="$3"
  shift 3

  local args_file="$tmp_dir/$case_name.args"
  local sky_file="$tmp_dir/$case_name.sky"
  local actual_message
  local exit_status

  env \
    CODEX_NOTIFY_SKY_CLIENT=/bin/echo \
    CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
    CODEX_NOTIFY_JQ="$jq_bin" \
    CODEX_NOTIFY_LOG_FILE="$log_file" \
    CODEX_NOTIFY_CAPTURE_FILE="$args_file" \
    "$@" \
    "$wrapper" "$case_payload" > "$sky_file"
  exit_status=$?

  assert_equal 0 "$exit_status" "$case_name exits successfully"
  if ! wait_for_file_contains "$args_file" '-message'; then
    print -u2 "FAIL: $case_name records a notification body"
    (( failures += 1 ))
  else
    actual_message="$(argument_after_flag "$args_file" '-message')"
    assert_equal "$expected_message" "$actual_message" "$case_name notification body"
  fi
  assert_equal "turn-ended $case_payload" "$(<"$sky_file")" \
    "$case_name preserves the exact Sky payload"
}

run_permission_case() {
  local case_name="$1"
  local case_payload="$2"
  local expected_message="$3"
  local expected_project="$4"
  local permission_jq="${5:-$jq_bin}"
  local args_file="$tmp_dir/$case_name.permission.args"
  local stdout_file="$tmp_dir/$case_name.permission.stdout"
  local case_log="$tmp_dir/$case_name.permission.log"
  local actual_message
  local exit_status

  /usr/bin/printf '%s' "$case_payload" | env \
    CODEX_PERMISSION_NOTIFY_WRAPPER="$wrapper" \
    CODEX_PERMISSION_NOTIFY_JQ="$permission_jq" \
    CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
    CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
    CODEX_NOTIFY_JQ="$jq_bin" \
    CODEX_NOTIFY_LOG_FILE="$case_log" \
    CODEX_NOTIFY_CAPTURE_FILE="$args_file" \
      "$permission_adapter" > "$stdout_file"
  exit_status=$?

  assert_equal 0 "$exit_status" "$case_name exits successfully"
  assert_equal '' "$(<"$stdout_file")" "$case_name keeps hook stdout empty"
  if ! wait_for_file_contains "$args_file" '-message'; then
    print -u2 "FAIL: $case_name records a permission notification"
    (( failures += 1 ))
    return
  fi

  actual_message="$(argument_after_flag "$args_file" '-message')"
  assert_equal "$expected_message" "$actual_message" "$case_name notification body"
  assert_default_sound "$args_file" \
    "$case_name uses the macOS default notification sound"
  assert_file_contains "$args_file" 'Codex' "$case_name notification title"
  assert_file_contains "$args_file" 'com.mitchellh.ghostty' "$case_name click target"
  assert_file_not_contains "$case_log" 'component=SkyComputerUseClient' \
    "$case_name does not invoke Sky"

  if [[ -n "$expected_project" ]]; then
    assert_equal "$expected_project" "$(argument_after_flag "$args_file" '-subtitle')" \
      "$case_name project subtitle"
  else
    assert_file_not_contains "$args_file" '-subtitle' "$case_name omits an invalid project"
  fi
}

readonly payload='{"type":"agent-turn-complete","cwd":"/portable-user/doc/sample-project","last-assistant-message":"done"}'

# Case 1: both backends receive their public arguments.
native_args="$tmp_dir/native-success.args"
output="$(
  CODEX_NOTIFY_SKY_CLIENT=/bin/echo \
  CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
  CODEX_NOTIFY_JQ="$jq_bin" \
  CODEX_NOTIFY_LOG_FILE="$log_file" \
  CODEX_NOTIFY_CAPTURE_FILE="$native_args" \
    "$wrapper" "$payload"
)"
exit_status=$?
assert_equal 0 "$exit_status" 'both backends return success'
if ! wait_for_file_contains "$native_args" '-title'; then
  print -u2 'FAIL: native notifier records its arguments'
  (( failures += 1 ))
fi
assert_file_contains "$native_args" '-title' 'native notification title flag'
assert_file_contains "$native_args" 'Codex' 'native notification title'
assert_file_contains "$native_args" '-message' 'native notification body flag'
assert_equal 'done' "$(argument_after_flag "$native_args" '-message')" \
  'native notification uses the assistant summary'
assert_default_sound "$native_args" \
  'completion uses the macOS default notification sound'
assert_file_not_contains "$native_args" '-sender' 'Terminal Notifier remains the notification sender'
assert_file_contains "$native_args" '-activate' 'Ghostty click target flag'
assert_file_contains "$native_args" 'com.mitchellh.ghostty' 'Ghostty click target'
assert_file_contains "$native_args" '-subtitle' 'project subtitle flag'
assert_file_contains "$native_args" 'sample-project' 'project subtitle from cwd'
assert_contains "$output" "turn-ended $payload" 'Sky receives the unchanged payload'

run_message_case \
  'normalized-summary' \
  '{"type":"agent-turn-complete","cwd":"/portable-user/normalized","last-assistant-message":"  已完成\n\n修改\t 三個檔案  "}' \
  '已完成 修改 三個檔案'

run_message_case \
  'missing-summary' \
  '{"type":"agent-turn-complete","cwd":"/portable-user/missing"}' \
  '任務已完成'

run_message_case \
  'non-string-summary' \
  '{"type":"agent-turn-complete","last-assistant-message":42}' \
  '任務已完成'

run_message_case \
  'blank-summary' \
  '{"type":"agent-turn-complete","last-assistant-message":" \n\t  "}' \
  '任務已完成'

run_message_case \
  'invalid-json' \
  'not-json' \
  '任務已完成'

run_message_case \
  'missing-jq' \
  '{"type":"agent-turn-complete","last-assistant-message":"不可解析"}' \
  '任務已完成' \
  CODEX_NOTIFY_JQ="$tmp_dir/missing-jq"

run_message_case \
  'ignores-input-messages' \
  '{"type":"agent-turn-complete","input-messages":["不要放進通知"]}' \
  '任務已完成'

long_message=''
expected_default_limit=''
for _ in {1..161}; do
  long_message+='界'
done
for _ in {1..159}; do
  expected_default_limit+='界'
done
expected_default_limit+='…'

long_payload="$(
  "$jq_bin" -cn \
    --arg message "$long_message" \
    '{"type":"agent-turn-complete","cwd":"/portable-user/default-limit","last-assistant-message":$message}'
)"

run_message_case \
  'default-160-character-limit' \
  "$long_payload" \
  "$expected_default_limit"

run_message_case \
  'exact-custom-limit' \
  '{"type":"agent-turn-complete","last-assistant-message":"一二三四五六"}' \
  '一二三四五六' \
  CODEX_NOTIFY_MAX_MESSAGE_CHARS=6

run_message_case \
  'over-custom-limit' \
  '{"type":"agent-turn-complete","last-assistant-message":"一二三四五六七"}' \
  '一二三四五…' \
  CODEX_NOTIFY_MAX_MESSAGE_CHARS=6

run_message_case \
  'invalid-text-limit' \
  "$long_payload" \
  "$expected_default_limit" \
  CODEX_NOTIFY_MAX_MESSAGE_CHARS=invalid

run_message_case \
  'below-minimum-limit' \
  "$long_payload" \
  "$expected_default_limit" \
  CODEX_NOTIFY_MAX_MESSAGE_CHARS=1

run_message_case \
  'minimum-valid-limit' \
  '{"type":"agent-turn-complete","last-assistant-message":"一二三"}' \
  '一…' \
  CODEX_NOTIFY_MAX_MESSAGE_CHARS=2

run_message_case \
  'unicode-limit-with-c-locale' \
  '{"type":"agent-turn-complete","last-assistant-message":"一二三"}' \
  '一…' \
  CODEX_NOTIFY_MAX_MESSAGE_CHARS=2 \
  LC_ALL=C

run_message_case \
  'normalized-custom-fallback' \
  '{"type":"agent-turn-complete"}' \
  '自訂 完成' \
  CODEX_NOTIFY_FALLBACK_MESSAGE=$'  自訂\n\t完成  '

run_message_case \
  'blank-custom-fallback' \
  '{"type":"agent-turn-complete"}' \
  '任務已完成' \
  CODEX_NOTIFY_FALLBACK_MESSAGE=$' \n\t '

run_message_case \
  'limited-custom-fallback' \
  '{"type":"agent-turn-complete"}' \
  '一二三…' \
  CODEX_NOTIFY_MAX_MESSAGE_CHARS=4 \
  CODEX_NOTIFY_FALLBACK_MESSAGE='一二三四五'

run_message_case \
  'custom-fallback-without-jq' \
  '{"type":"agent-turn-complete","last-assistant-message":"不可解析"}' \
  '解析器不可用' \
  CODEX_NOTIFY_JQ="$tmp_dir/missing-jq" \
  CODEX_NOTIFY_FALLBACK_MESSAGE='解析器不可用'

# When Sky invokes this wrapper as --previous-notify, native-only mode must not
# send the same completion back to Sky.
native_only_args="$tmp_dir/native-only.args"
native_only_log="$tmp_dir/native-only.log"
CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
CODEX_NOTIFY_JQ="$jq_bin" \
CODEX_NOTIFY_LOG_FILE="$native_only_log" \
CODEX_NOTIFY_CAPTURE_FILE="$native_only_args" \
  "$wrapper" --native-only "$payload"
exit_status=$?

assert_equal 0 "$exit_status" 'native-only mode returns success'
assert_equal 'done' "$(argument_after_flag "$native_only_args" '-message')" \
  'native-only mode uses the real payload'
assert_file_contains "$native_only_args" 'sample-project' \
  'native-only mode preserves the project subtitle'
assert_file_not_contains "$native_only_log" 'component=SkyComputerUseClient' \
  'native-only mode does not invoke Sky again'

# Case 2: native notifier failure does not block Sky.
native_args="$tmp_dir/native-failure.args"
output="$(
  CODEX_NOTIFY_SKY_CLIENT=/bin/echo \
  CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
  CODEX_NOTIFY_JQ="$jq_bin" \
  CODEX_NOTIFY_LOG_FILE="$log_file" \
  CODEX_NOTIFY_CAPTURE_FILE="$native_args" \
  CODEX_NOTIFY_EXIT_CODE=1 \
    "$wrapper" "$payload"
)"
exit_status=$?
assert_equal 0 "$exit_status" 'native notifier failure is isolated'
assert_contains "$output" "turn-ended $payload" 'Sky still runs after native notifier failure'
if ! wait_for_file_contains "$log_file" 'component=terminal-notifier exit=1'; then
  print -u2 'FAIL: native notifier failure is logged'
  (( failures += 1 ))
fi

# Case 3: Sky failure does not block the native notifier.
native_args="$tmp_dir/native-after-sky-failure.args"
output="$(
  CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
  CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
  CODEX_NOTIFY_JQ="$jq_bin" \
  CODEX_NOTIFY_LOG_FILE="$log_file" \
  CODEX_NOTIFY_CAPTURE_FILE="$native_args" \
    "$wrapper" "$payload"
)"
exit_status=$?
assert_equal 0 "$exit_status" 'Sky failure is isolated'
if ! wait_for_file_contains "$native_args" 'Codex'; then
  print -u2 'FAIL: native notifier runs after Sky failure'
  (( failures += 1 ))
fi
assert_file_contains "$native_args" 'Codex' 'native notifier still runs after Sky failure'
assert_file_contains "$log_file" 'component=SkyComputerUseClient exit=1' 'Sky failure is logged'

# Case 4: missing payload uses a valid empty JSON object.
output="$(
  CODEX_NOTIFY_SKY_CLIENT=/bin/echo \
  CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
  CODEX_NOTIFY_JQ="$jq_bin" \
  CODEX_NOTIFY_LOG_FILE="$log_file" \
  CODEX_NOTIFY_CAPTURE_FILE="$tmp_dir/native-empty-payload.args" \
    "$wrapper"
)"
exit_status=$?
assert_equal 0 "$exit_status" 'missing payload is accepted'
assert_contains "$output" 'turn-ended {}' 'missing payload defaults to an empty object'

# Case 5: the wrapper waits until the native notifier submits its request.
sync_output="$tmp_dir/sync-wrapper.out"
sync_args="$tmp_dir/sync-native.args"
sync_pid_file="$tmp_dir/sync-native.pid"
sync_done_file="$tmp_dir/sync-native.done"
CODEX_NOTIFY_SKY_CLIENT=/bin/echo \
CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
CODEX_NOTIFY_JQ="$jq_bin" \
CODEX_NOTIFY_LOG_FILE="$log_file" \
CODEX_NOTIFY_CAPTURE_FILE="$sync_args" \
CODEX_NOTIFY_PID_FILE="$sync_pid_file" \
CODEX_NOTIFY_DONE_FILE="$sync_done_file" \
CODEX_NOTIFY_HOLD_SECONDS=0.5 \
  "$wrapper" "$payload" > "$sync_output"
exit_status=$?

assert_equal 0 "$exit_status" 'wrapper returns after native notifier completion'
assert_file_contains "$sync_output" "turn-ended $payload" 'Sky runs after native notifier completion'
assert_file_contains "$sync_args" '-activate' 'native notifier receives click target'

if [[ ! -f "$sync_done_file" ]]; then
  print -u2 'FAIL: wrapper exits before native notifier finishes'
  (( failures += 1 ))
  for attempt in {1..10}; do
    [[ -f "$sync_pid_file" ]] && break
    /bin/sleep 0.01
  done
  if [[ -f "$sync_pid_file" ]]; then
    sync_pid="$(<"$sync_pid_file")"
    kill "$sync_pid" 2>/dev/null || true
  fi
fi

# PermissionRequest hooks must bypass Yazelix terminal notifications and reuse
# the independent native-only Terminal Notifier path without making a decision.
if [[ ! -x "$permission_adapter" ]]; then
  print -u2 'FAIL: permission notification adapter is missing or not executable'
  (( failures += 1 ))
else
  run_permission_case \
    'permission-command' \
    '{"hook_event_name":"PermissionRequest","cwd":"/portable-user/project-alpha","tool_name":"Bash","tool_input":{"command":"open -a Calculator"}}' \
    '等待權限核准：open -a Calculator' \
    'project-alpha'

  run_permission_case \
    'permission-command-array' \
    '{"hook_event_name":"PermissionRequest","cwd":"/portable-user/project-array","tool_name":"Bash","tool_input":{"command":["git","status"]}}' \
    '等待權限核准：git status' \
    'project-array'

  run_permission_case \
    'permission-tool-fallback' \
    '{"hook_event_name":"PermissionRequest","cwd":"/portable-user/project-tool","tool_name":"mcp__example__write","tool_input":{}}' \
    '等待權限核准：mcp__example__write' \
    'project-tool'

  run_permission_case \
    'permission-invalid-json' \
    'not-json' \
    '等待權限核准' \
    ''

  run_permission_case \
    'permission-missing-parser' \
    '{"hook_event_name":"PermissionRequest","cwd":"/portable-user/no-parser","tool_name":"Bash","tool_input":{"command":"ignored"}}' \
    '等待權限核准' \
    '' \
    "$tmp_dir/missing-permission-jq"

  missing_wrapper_log="$tmp_dir/permission-missing-wrapper.log"
  missing_wrapper_stdout="$tmp_dir/permission-missing-wrapper.stdout"
  /usr/bin/printf '%s' '{}' | env \
    CODEX_PERMISSION_NOTIFY_WRAPPER="$tmp_dir/missing-wrapper" \
    CODEX_PERMISSION_NOTIFY_JQ="$jq_bin" \
    CODEX_NOTIFY_LOG_FILE="$missing_wrapper_log" \
      "$permission_adapter" > "$missing_wrapper_stdout"
  exit_status=$?
  assert_equal 0 "$exit_status" 'missing permission wrapper remains non-blocking'
  assert_equal '' "$(<"$missing_wrapper_stdout")" \
    'missing permission wrapper keeps hook stdout empty'
  assert_file_contains "$missing_wrapper_log" 'component=permission-notify-wrapper exit=127' \
    'missing permission wrapper is logged'
fi

# Plain Ghostty must submit notifications through its originating tty so macOS
# associates the banner and click action with the source terminal.
plain_completion_tty="$tmp_dir/plain-completion.tty"
plain_completion_args="$tmp_dir/plain-completion.args"
: > "$plain_completion_tty"
/usr/bin/env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID \
  TERM_PROGRAM=ghostty \
  CODEX_NOTIFY_TTY="$plain_completion_tty" \
  CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
  CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
  CODEX_NOTIFY_JQ="$jq_bin" \
  CODEX_NOTIFY_LOG_FILE="$tmp_dir/plain-completion.log" \
  CODEX_NOTIFY_CAPTURE_FILE="$plain_completion_args" \
    "$wrapper" --native-only \
      '{"last-assistant-message":"plain done"}'
exit_status=$?

assert_equal 0 "$exit_status" 'plain Ghostty completion remains non-blocking'
assert_equal '1b5d393b706c61696e20646f6e6507' \
  "$(hex_file "$plain_completion_tty")" \
  'plain Ghostty completion emits OSC 9 with the dynamic body'
assert_file_not_contains "$plain_completion_args" '-message' \
  'plain Ghostty completion skips Terminal Notifier after OSC success'

plain_permission_tty="$tmp_dir/plain-permission.tty"
plain_permission_expected="$tmp_dir/plain-permission.expected"
plain_permission_args="$tmp_dir/plain-permission.args"
plain_permission_stdout="$tmp_dir/plain-permission.stdout"
plain_permission_message='等待權限核准：open -a Calculator'
: > "$plain_permission_tty"
/usr/bin/printf '\033]9;%s\007' "$plain_permission_message" \
  > "$plain_permission_expected"
/usr/bin/printf '%s' \
  '{"hook_event_name":"PermissionRequest","cwd":"/portable-user/plain-permission","tool_name":"Bash","tool_input":{"command":"open -a Calculator"}}' | \
  /usr/bin/env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID \
    TERM_PROGRAM=ghostty \
    CODEX_PERMISSION_NOTIFY_WRAPPER="$wrapper" \
    CODEX_PERMISSION_NOTIFY_JQ="$jq_bin" \
    CODEX_NOTIFY_TTY="$plain_permission_tty" \
    CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
    CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
    CODEX_NOTIFY_JQ="$jq_bin" \
    CODEX_NOTIFY_LOG_FILE="$tmp_dir/plain-permission.log" \
    CODEX_NOTIFY_CAPTURE_FILE="$plain_permission_args" \
      "$permission_adapter" > "$plain_permission_stdout"
exit_status=$?

assert_equal 0 "$exit_status" 'plain Ghostty permission remains non-blocking'
assert_equal '' "$(/bin/cat "$plain_permission_stdout")" \
  'plain Ghostty permission keeps hook stdout empty'
assert_equal "$(hex_file "$plain_permission_expected")" \
  "$(hex_file "$plain_permission_tty")" \
  'plain Ghostty permission emits the exact dynamic OSC 9 body'
assert_file_not_contains "$plain_permission_args" '-message' \
  'plain Ghostty permission skips Terminal Notifier after OSC success'

# Any Zellij marker wins over TERM_PROGRAM=ghostty. Incomplete routing metadata
# must remain on the Terminal Notifier fallback instead of leaking OSC to a tty.
for marker_case in zellij session pane; do
  marker_tty="$tmp_dir/$marker_case-marker.tty"
  marker_args="$tmp_dir/$marker_case-marker.args"
  : > "$marker_tty"

  case "$marker_case" in
    zellij) marker_assignment='ZELLIJ=0' ;;
    session) marker_assignment='ZELLIJ_SESSION_NAME=session-only' ;;
    pane) marker_assignment='ZELLIJ_PANE_ID=7' ;;
  esac

  /usr/bin/env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID \
    TERM_PROGRAM=ghostty \
    "$marker_assignment" \
    CODEX_NOTIFY_TTY="$marker_tty" \
    CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
    CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
    CODEX_NOTIFY_JQ="$jq_bin" \
    CODEX_NOTIFY_LOG_FILE="$tmp_dir/$marker_case-marker.log" \
    CODEX_NOTIFY_CAPTURE_FILE="$marker_args" \
      "$wrapper" --native-only \
        '{"last-assistant-message":"zellij marker"}'
  exit_status=$?

  assert_equal 0 "$exit_status" "$marker_case marker remains non-blocking"
  assert_equal '' "$(hex_file "$marker_tty")" \
    "$marker_case marker suppresses Ghostty OSC 9"
  assert_file_contains "$marker_args" '-message' \
    "$marker_case marker uses Terminal Notifier"
  assert_default_sound "$marker_args" \
    "$marker_case marker uses the macOS default notification sound"
  assert_file_contains "$marker_args" '-activate' \
    "$marker_case marker retains Ghostty activation fallback"
done

unavailable_tty_args="$tmp_dir/unavailable-tty.args"
unavailable_tty_log="$tmp_dir/unavailable-tty.log"
/usr/bin/env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID \
  TERM_PROGRAM=ghostty \
  CODEX_NOTIFY_TTY="$tmp_dir/missing-tty-directory/tty" \
  CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
  CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
  CODEX_NOTIFY_JQ="$jq_bin" \
  CODEX_NOTIFY_LOG_FILE="$unavailable_tty_log" \
  CODEX_NOTIFY_CAPTURE_FILE="$unavailable_tty_args" \
    "$wrapper" --native-only \
      '{"last-assistant-message":"fallback body"}'
exit_status=$?

assert_equal 0 "$exit_status" 'unavailable tty fallback remains non-blocking'
assert_file_contains "$unavailable_tty_args" '-message' \
  'unavailable tty falls back to Terminal Notifier'
assert_default_sound "$unavailable_tty_args" \
  'unavailable tty fallback uses the macOS default notification sound'
assert_file_contains "$unavailable_tty_args" '-activate' \
  'unavailable tty fallback activates Ghostty'
assert_file_contains "$unavailable_tty_log" 'component=ghostty-osc9 exit=' \
  'unavailable tty failure is logged'

unsafe_tty="$tmp_dir/unsafe-body.tty"
unsafe_expected="$tmp_dir/unsafe-body.expected"
unsafe_args="$tmp_dir/unsafe-body.args"
unsafe_message=$'safe\e]9;evil\aend'
unsafe_payload="$(
  "$jq_bin" -cn \
    --arg message "$unsafe_message" \
    '{"last-assistant-message":$message}'
)"
: > "$unsafe_tty"
/usr/bin/printf '\033]9;%s\007' 'safe]9;evilend' > "$unsafe_expected"
/usr/bin/env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID \
  TERM_PROGRAM=ghostty \
  CODEX_NOTIFY_TTY="$unsafe_tty" \
  CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
  CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
  CODEX_NOTIFY_JQ="$jq_bin" \
  CODEX_NOTIFY_LOG_FILE="$tmp_dir/unsafe-body.log" \
  CODEX_NOTIFY_CAPTURE_FILE="$unsafe_args" \
    "$wrapper" --native-only "$unsafe_payload"
exit_status=$?

assert_equal 0 "$exit_status" 'OSC control sanitization remains non-blocking'
assert_equal "$(hex_file "$unsafe_expected")" "$(hex_file "$unsafe_tty")" \
  'OSC body removes ESC and BEL while preserving framing'
assert_file_not_contains "$unsafe_args" '-message' \
  'sanitized plain Ghostty notification skips Terminal Notifier'

# A configured route command replaces the coarse Ghostty activation for both
# completion and permission notifications.
completion_route_args="$tmp_dir/completion-route.args"
CODEX_NOTIFY_ROUTE_HELPER=/bin/echo \
CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
CODEX_NOTIFY_JQ="$jq_bin" \
CODEX_NOTIFY_LOG_FILE="$tmp_dir/completion-route.log" \
CODEX_NOTIFY_CAPTURE_FILE="$completion_route_args" \
  "$wrapper" --native-only "$payload"
exit_status=$?

assert_equal 0 "$exit_status" 'routable completion remains non-blocking'
assert_file_contains "$completion_route_args" '-execute' \
  'routable completion uses execute'
assert_default_sound "$completion_route_args" \
  'routable completion uses the macOS default notification sound'
assert_equal 'build' "$(argument_after_flag "$completion_route_args" '-execute')" \
  'routable completion preserves the route command'
assert_file_not_contains "$completion_route_args" '-activate' \
  'routable completion omits coarse activation'

permission_route_args="$tmp_dir/permission-route.args"
permission_route_stdout="$tmp_dir/permission-route.stdout"
/usr/bin/printf '%s' \
  '{"hook_event_name":"PermissionRequest","cwd":"/portable-user/permission-route","tool_name":"Bash","tool_input":{"command":"open -a Calculator"}}' | env \
  CODEX_PERMISSION_NOTIFY_WRAPPER="$wrapper" \
  CODEX_PERMISSION_NOTIFY_JQ="$jq_bin" \
  CODEX_NOTIFY_ROUTE_HELPER=/bin/echo \
  CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
  CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
  CODEX_NOTIFY_JQ="$jq_bin" \
  CODEX_NOTIFY_LOG_FILE="$tmp_dir/permission-route.log" \
  CODEX_NOTIFY_CAPTURE_FILE="$permission_route_args" \
    "$permission_adapter" > "$permission_route_stdout"
exit_status=$?

assert_equal 0 "$exit_status" 'routable permission remains non-blocking'
permission_route_output=''
if [[ -f "$permission_route_stdout" ]]; then
  permission_route_output="$(<"$permission_route_stdout")"
fi
assert_equal '' "$permission_route_output" \
  'routable permission keeps hook stdout empty'
assert_file_contains "$permission_route_args" '-execute' \
  'routable permission uses the shared execute path'
assert_default_sound "$permission_route_args" \
  'routable permission uses the macOS default notification sound'
assert_file_not_contains "$permission_route_args" '-activate' \
  'routable permission omits coarse activation'

# Empty and failed builders retain the established Ghostty activation fallback.
for builder_case in empty failed; do
  builder_args="$tmp_dir/builder-$builder_case.args"
  if [[ "$builder_case" == empty ]]; then
    builder_command=/usr/bin/true
  else
    builder_command=/usr/bin/false
  fi

  CODEX_NOTIFY_ROUTE_HELPER="$builder_command" \
  CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
  CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
  CODEX_NOTIFY_JQ="$jq_bin" \
  CODEX_NOTIFY_LOG_FILE="$tmp_dir/builder-$builder_case.log" \
  CODEX_NOTIFY_CAPTURE_FILE="$builder_args" \
    "$wrapper" --native-only "$payload"

  assert_file_contains "$builder_args" '-activate' \
    "$builder_case route builder keeps activation fallback"
  assert_file_not_contains "$builder_args" '-execute' \
    "$builder_case route builder omits execute"
done

if [[ ! -x "$route_helper" ]]; then
  print -u2 'FAIL: exact notification route helper is missing or not executable'
  (( failures += 1 ))
else
  readonly route_session='curious-salamander'
  readonly route_pane='2'
  readonly route_terminal_id='04E67EB2-B11F-4C47-94CC-ED1550FA0978'
  route_build_osascript_args="$tmp_dir/route-build-osascript.args"
  route_command="$({
    ZELLIJ_SESSION_NAME="$route_session" \
    ZELLIJ_PANE_ID="$route_pane" \
    CODEX_ROUTE_JQ="$jq_bin" \
    CODEX_ROUTE_OSASCRIPT="$recording_osascript" \
    CODEX_ROUTE_ZELLIJ_BIN="$recording_zellij" \
    CODEX_ROUTE_TERMINAL_ID="$route_terminal_id" \
    CODEX_ROUTE_OSASCRIPT_CAPTURE_FILE="$route_build_osascript_args" \
      "$route_helper" build
  } 2>"$tmp_dir/route-build.stderr")"
  exit_status=$?

  assert_equal 0 "$exit_status" 'route build exits successfully'
  assert_contains "$route_command" ' click ' \
    'route build returns a shell-safe click command'
  assert_not_contains "$route_command" "$route_session" \
    'route command hides the raw session name'
  assert_not_contains "$route_command" "$route_terminal_id" \
    'route command hides the raw terminal id'
  assert_equal "$route_session" \
    "$(argument_after_flag "$route_build_osascript_args" '-')" \
    'route build asks Ghostty for the matching session title'

  # Nova exposes its packaged Zellij client through YZX_ZELLIJ rather than
  # adding it to PATH. The route must still be exact in that environment.
  nova_route_build_osascript_args="$tmp_dir/nova-route-build-osascript.args"
  nova_route_command="$({
    /usr/bin/env -u CODEX_ROUTE_ZELLIJ_BIN \
      PATH=/usr/bin:/bin \
      YZX_ZELLIJ="$recording_zellij" \
      ZELLIJ_SESSION_NAME="$route_session" \
      ZELLIJ_PANE_ID="$route_pane" \
      CODEX_ROUTE_JQ="$jq_bin" \
      CODEX_ROUTE_OSASCRIPT="$recording_osascript" \
      CODEX_ROUTE_TERMINAL_ID="$route_terminal_id" \
      CODEX_ROUTE_OSASCRIPT_CAPTURE_FILE="$nova_route_build_osascript_args" \
        "$route_helper" build
  } 2>"$tmp_dir/nova-route-build.stderr")"
  exit_status=$?

  assert_equal 0 "$exit_status" \
    'Nova route build remains non-blocking without Zellij on PATH'
  assert_contains "$nova_route_command" ' click ' \
    'Nova packaged Zellij path builds an exact click route'
  assert_equal "$route_session" \
    "$(argument_after_flag "$nova_route_build_osascript_args" '-')" \
    'Nova route build resolves the originating Ghostty terminal'

  route_zellij_args="$tmp_dir/route-click-zellij.args"
  route_focus_args="$tmp_dir/route-click-osascript.args"
  route_open_args="$tmp_dir/route-click-open.args"
  route_click_stdout="$tmp_dir/route-click.stdout"
  CODEX_ROUTE_JQ="$jq_bin" \
  CODEX_ROUTE_OSASCRIPT="$recording_osascript" \
  CODEX_ROUTE_OPEN="$recording_open" \
  CODEX_ROUTE_ZELLIJ_BIN="$recording_zellij" \
  CODEX_ROUTE_ZELLIJ_CAPTURE_FILE="$route_zellij_args" \
  CODEX_ROUTE_OSASCRIPT_CAPTURE_FILE="$route_focus_args" \
  CODEX_ROUTE_OPEN_CAPTURE_FILE="$route_open_args" \
  CODEX_ROUTE_LOG_FILE="$tmp_dir/route-click.log" \
    /bin/sh -c "$route_command" > "$route_click_stdout"
  exit_status=$?

  assert_equal 0 "$exit_status" 'successful route click exits successfully'
  assert_equal '' "$(<"$route_click_stdout")" \
    'successful route click keeps stdout empty'
  assert_equal "$route_session" \
    "$(argument_after_flag "$route_zellij_args" '--session')" \
    'route click selects the captured Zellij session'
  assert_equal "$route_pane" \
    "$(argument_after_flag "$route_zellij_args" 'focus-pane-id')" \
    'route click selects the captured Zellij pane'
  assert_equal "$route_terminal_id" \
    "$(argument_after_flag "$route_focus_args" '-')" \
    'route click focuses the captured Ghostty terminal'
  assert_file_contains "$route_focus_args" "$route_session" \
    'route click passes the session fallback as AppleScript argv'
  assert_file_not_contains "$route_open_args" 'com.mitchellh.ghostty' \
    'successful route click does not use fallback open'

  already_focused_open_args="$tmp_dir/already-focused-open.args"
  already_focused_osascript_args="$tmp_dir/already-focused-osascript.args"
  CODEX_ROUTE_JQ="$jq_bin" \
  CODEX_ROUTE_OSASCRIPT="$recording_osascript" \
  CODEX_ROUTE_OPEN="$recording_open" \
  CODEX_ROUTE_ZELLIJ_BIN="$recording_zellij" \
  CODEX_ROUTE_ZELLIJ_CAPTURE_FILE="$tmp_dir/already-focused-zellij.args" \
  CODEX_ROUTE_ZELLIJ_EXIT_CODE=2 \
  CODEX_ROUTE_ZELLIJ_STDERR="Pane Terminal($route_pane) is already focused" \
  CODEX_ROUTE_OSASCRIPT_CAPTURE_FILE="$already_focused_osascript_args" \
  CODEX_ROUTE_OPEN_CAPTURE_FILE="$already_focused_open_args" \
  CODEX_ROUTE_LOG_FILE="$tmp_dir/already-focused.log" \
    /bin/sh -c "$route_command" > "$tmp_dir/already-focused.stdout"
  exit_status=$?

  assert_equal 0 "$exit_status" 'already-focused pane remains non-blocking'
  assert_file_contains "$already_focused_osascript_args" "$route_terminal_id" \
    'already-focused pane still focuses the Ghostty terminal'
  assert_file_not_contains "$already_focused_open_args" 'com.mitchellh.ghostty' \
    'already-focused pane is treated as a successful route'

  # Without a Zellij context, the real builder emits no command and the wrapper
  # retains -activate even if the caller itself is running inside Yazelix.
  no_context_args="$tmp_dir/no-context-route.args"
  /usr/bin/env -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID \
    CODEX_NOTIFY_ROUTE_HELPER="$route_helper" \
    CODEX_NOTIFY_SKY_CLIENT=/usr/bin/false \
    CODEX_NOTIFY_TERMINAL_NOTIFIER="$recording_notifier" \
    CODEX_NOTIFY_JQ="$jq_bin" \
    CODEX_NOTIFY_LOG_FILE="$tmp_dir/no-context-route.log" \
    CODEX_NOTIFY_CAPTURE_FILE="$no_context_args" \
      "$wrapper" --native-only "$payload"
  assert_file_contains "$no_context_args" '-activate' \
    'missing Zellij context keeps activation fallback'
  assert_file_not_contains "$no_context_args" '-execute' \
    'missing Zellij context does not create a route command'

  # Invalid tokens and stale route components are non-blocking and open Ghostty.
  invalid_open_args="$tmp_dir/invalid-token-open.args"
  invalid_stdout="$tmp_dir/invalid-token.stdout"
  CODEX_ROUTE_JQ="$jq_bin" \
  CODEX_ROUTE_OPEN="$recording_open" \
  CODEX_ROUTE_OPEN_CAPTURE_FILE="$invalid_open_args" \
  CODEX_ROUTE_LOG_FILE="$tmp_dir/invalid-token.log" \
    "$route_helper" click 'not-base64!' > "$invalid_stdout"
  exit_status=$?
  assert_equal 0 "$exit_status" 'invalid token remains non-blocking'
  assert_equal '' "$(<"$invalid_stdout")" 'invalid token keeps stdout empty'
  assert_equal 'com.mitchellh.ghostty' \
    "$(argument_after_flag "$invalid_open_args" '-b')" \
    'invalid token opens Ghostty fallback'

  zellij_failure_open_args="$tmp_dir/zellij-failure-open.args"
  CODEX_ROUTE_JQ="$jq_bin" \
  CODEX_ROUTE_OSASCRIPT="$recording_osascript" \
  CODEX_ROUTE_OPEN="$recording_open" \
  CODEX_ROUTE_ZELLIJ_BIN="$recording_zellij" \
  CODEX_ROUTE_ZELLIJ_CAPTURE_FILE="$tmp_dir/zellij-failure.args" \
  CODEX_ROUTE_ZELLIJ_EXIT_CODE=1 \
  CODEX_ROUTE_OSASCRIPT_CAPTURE_FILE="$tmp_dir/zellij-failure-osascript.args" \
  CODEX_ROUTE_OPEN_CAPTURE_FILE="$zellij_failure_open_args" \
  CODEX_ROUTE_LOG_FILE="$tmp_dir/zellij-failure.log" \
    /bin/sh -c "$route_command" > "$tmp_dir/zellij-failure.stdout"
  exit_status=$?
  assert_equal 0 "$exit_status" 'stale Zellij route remains non-blocking'
  assert_equal 'com.mitchellh.ghostty' \
    "$(argument_after_flag "$zellij_failure_open_args" '-b')" \
    'stale Zellij route opens Ghostty fallback'

  osascript_failure_open_args="$tmp_dir/osascript-failure-open.args"
  CODEX_ROUTE_JQ="$jq_bin" \
  CODEX_ROUTE_OSASCRIPT="$recording_osascript" \
  CODEX_ROUTE_OSASCRIPT_EXIT_CODE=1 \
  CODEX_ROUTE_OPEN="$recording_open" \
  CODEX_ROUTE_ZELLIJ_BIN="$recording_zellij" \
  CODEX_ROUTE_ZELLIJ_CAPTURE_FILE="$tmp_dir/osascript-failure-zellij.args" \
  CODEX_ROUTE_OSASCRIPT_CAPTURE_FILE="$tmp_dir/osascript-failure.args" \
  CODEX_ROUTE_OPEN_CAPTURE_FILE="$osascript_failure_open_args" \
  CODEX_ROUTE_LOG_FILE="$tmp_dir/osascript-failure.log" \
    /bin/sh -c "$route_command" > "$tmp_dir/osascript-failure.stdout"
  exit_status=$?
  assert_equal 0 "$exit_status" 'stale Ghostty route remains non-blocking'
  assert_equal 'com.mitchellh.ghostty' \
    "$(argument_after_flag "$osascript_failure_open_args" '-b')" \
    'stale Ghostty route opens Ghostty fallback'
fi

if (( failures > 0 )); then
  print -u2 "FAIL: $failures assertion(s) failed"
  exit 1
fi

print 'PASS: codex-notify behavior suite'

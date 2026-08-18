#!/bin/zsh

set -u
unsetopt BG_NICE

readonly test_dir="${0:A:h}"
readonly module_dir="${test_dir:h}"
readonly installer="$module_dir/../scripts/yazelix_setup.sh"
readonly fake_nix="$test_dir/fixtures/fake-nix.zsh"
readonly tmp_dir="$(/usr/bin/mktemp -d)"
readonly expected_profile_args=$'--option\ndownload-attempts\n1\nprofile\nadd\n--refresh\ngithub:Yazelix/nova/stable'
trap '/bin/rm -rf "$tmp_dir"' EXIT HUP INT TERM

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

run_setup() {
  local case_user_home="$1"
  shift

  /usr/bin/env \
    HOME="$case_user_home" \
    PATH="/usr/bin:/bin" \
    "$@" \
    "$installer"
}

missing_home="$tmp_dir/missing-home"
missing_output="$(run_setup "$missing_home" 2>&1)"
missing_status=$?
assert_equal 0 "$missing_status" 'missing Nix defers Yazelix without failing'
assert_contains "$missing_output" 'Yazelix installation deferred' \
  'missing Nix reports deferred Yazelix setup'

nix_home="$tmp_dir/nix-home"
nix_bin_dir="$tmp_dir/nix-bin"
nix_capture="$tmp_dir/nix.args"
/bin/mkdir -p "$nix_bin_dir"
/bin/ln -s "$fake_nix" "$nix_bin_dir/nix"
nix_output="$(run_setup "$nix_home" \
  PATH="$nix_bin_dir:/usr/bin:/bin" \
  YAZELIX_TEST_NIX_CAPTURE="$nix_capture" \
  2>&1)"
nix_status=$?
assert_equal 0 "$nix_status" 'available Nix installs Yazelix'
assert_equal "$expected_profile_args" \
  "$(/bin/cat "$nix_capture")" \
  'Yazelix installer invokes the canonical stable profile command'
assert_contains "$nix_output" 'Yazelix installed' \
  'successful Yazelix installation is reported'

transient_nix_capture="$tmp_dir/transient-nix.args"
transient_nix_output="$(run_setup "$tmp_dir/transient-nix-home" \
  PATH="$nix_bin_dir:/usr/bin:/bin" \
  YAZELIX_TEST_NIX_CAPTURE="$transient_nix_capture" \
  YAZELIX_TEST_NIX_FIRST_EXIT=23 \
  2>&1)"
transient_nix_status=$?
assert_equal 0 "$transient_nix_status" \
  'transient Nix profile failure succeeds on one retry'
assert_equal 2 "$(/bin/cat "${transient_nix_capture}.count")" \
  'transient Nix profile failure invokes Nix exactly twice'
assert_contains "$transient_nix_output" 'retrying once' \
  'transient Nix profile failure reports the bounded retry'
assert_contains "$transient_nix_output" 'Yazelix installed' \
  'successful Yazelix retry is reported'

failed_nix_capture="$tmp_dir/failed-nix.args"
failed_nix_output="$(run_setup "$tmp_dir/failed-nix-home" \
  PATH="$nix_bin_dir:/usr/bin:/bin" \
  YAZELIX_TEST_NIX_CAPTURE="$failed_nix_capture" \
  YAZELIX_TEST_NIX_EXIT=23 \
  2>&1)"
failed_nix_status=$?
assert_equal 23 "$failed_nix_status" \
  'failed Nix profile installation propagates its status'
assert_equal 2 "$(/bin/cat "${failed_nix_capture}.count")" \
  'persistent Nix profile failure stops after one retry'
assert_contains "$failed_nix_output" 'retrying once' \
  'persistent Nix profile failure reports the bounded retry'
assert_contains "$failed_nix_output" 'GitHub HTTP 429' \
  'persistent Nix profile failure explains GitHub rate limiting'
if [[ "$failed_nix_output" == *'Yazelix installed'* ]]; then
  print -u2 'FAIL: failed Nix profile installation reported success'
  (( failures += 1 ))
fi

official_capture="$tmp_dir/official-ref.args"
run_setup "$tmp_dir/official-ref-home" \
  PATH="$nix_bin_dir:/usr/bin:/bin" \
  YAZELIX_REF='github:unapproved/example' \
  YAZELIX_TEST_NIX_CAPTURE="$official_capture" \
  >/dev/null 2>&1
assert_equal "$expected_profile_args" \
  "$(/bin/cat "$official_capture")" \
  'Yazelix source remains the approved stable flake reference'

fallback_capture="$tmp_dir/fallback-nix.args"
run_setup "$tmp_dir/fallback-nix-home" \
  PATH="$nix_bin_dir:/usr/bin:/bin" \
  YAZELIX_NIX="$tmp_dir/nonexistent-nix" \
  YAZELIX_TEST_NIX_CAPTURE="$fallback_capture" \
  >/dev/null 2>&1
if [[ ! -f "$fallback_capture" ]]; then
  print -u2 'FAIL: invalid Nix override hid the executable on PATH'
  (( failures += 1 ))
fi

existing_home="$tmp_dir/existing-home"
existing_bin="$tmp_dir/existing-bin"
existing_capture="$tmp_dir/existing-nix.args"
existing_yzx_capture="$tmp_dir/existing-yzx.args"
/bin/mkdir -p "$existing_bin"
/usr/bin/printf '%s\n' \
  '#!/bin/sh' \
  '/usr/bin/printf "%s\\n" "$@" >> "$YAZELIX_TEST_YZX_CAPTURE"' \
  > "$existing_bin/yzx"
/bin/chmod 755 "$existing_bin/yzx"
existing_output="$(/usr/bin/env \
  HOME="$existing_home" \
  PATH="$existing_bin:/usr/bin:/bin" \
  YAZELIX_TEST_NIX_CAPTURE="$existing_capture" \
  YAZELIX_TEST_YZX_CAPTURE="$existing_yzx_capture" \
  "$installer" 2>&1)"
existing_status=$?
assert_equal 0 "$existing_status" 'existing Yazelix installation is a no-op'
assert_contains "$existing_output" 'already available' \
  'existing Yazelix installation is reported as current'
if [[ -e "$existing_capture" ]]; then
  print -u2 'FAIL: existing Yazelix installation invoked Nix unexpectedly'
  (( failures += 1 ))
fi
if [[ -e "$existing_yzx_capture" ]]; then
  print -u2 'FAIL: existing Yazelix command was launched unexpectedly'
  (( failures += 1 ))
fi

if (( failures > 0 )); then
  print -u2 "FAIL: $failures Yazelix installer assertion(s) failed"
  exit 1
fi

print 'PASS: Yazelix installer behavior'

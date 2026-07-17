#!/bin/zsh

set -u
unsetopt BG_NICE

readonly test_dir="${0:A:h}"
readonly repo_dir="${test_dir:h:h}"
readonly fixture_dir="$test_dir/fixtures"
readonly harness="$fixture_dir/nix-setup-harness.sh"
readonly fake_curl="$fixture_dir/fake-nix-curl.zsh"
readonly fake_spctl="$fixture_dir/fake-nix-spctl.zsh"
readonly fake_sudo="$fixture_dir/fake-nix-sudo.zsh"
readonly fake_installer="$fixture_dir/fake-nix-installer.zsh"
readonly fake_nix="$fixture_dir/fake-nix-command.zsh"
readonly tmp_dir="$(/usr/bin/mktemp -d)"
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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    print -u2 "FAIL: $label (unexpected '$needle')"
    (( failures += 1 ))
  fi
}

prepare_case() {
  local name="$1"

  case_dir="$tmp_dir/$name"
  case_user_dir="$case_dir/user"
  case_system_root="$case_dir/system-root"
  case_tmp="$case_dir/tmp"
  case_capture="$case_dir/commands"
  case_stdout="$case_dir/stdout"
  case_stderr="$case_dir/stderr"

  /bin/mkdir -p \
    "$case_user_dir" \
    "$case_tmp" \
    "$case_system_root/usr/bin" \
    "$case_system_root/usr/sbin"
  /bin/ln -s "$fake_curl" "$case_system_root/usr/bin/curl"
  /bin/ln -s "$fake_spctl" "$case_system_root/usr/sbin/spctl"
  /bin/ln -s "$fake_sudo" "$case_system_root/usr/bin/sudo"
  /bin/ln -s "$fake_installer" "$case_system_root/usr/sbin/installer"
}

run_setup() {
  local input_mode="$1"
  local input_value="$2"
  shift 2

  if [[ "$input_mode" == 'eof' ]]; then
    /usr/bin/env \
      HOME="$case_user_dir" \
      PATH="/usr/bin:/bin" \
      TMPDIR="$case_tmp" \
      CIDER_TEST_NIX_SYSTEM_ROOT="$case_system_root" \
      CIDER_TEST_NIX_CAPTURE="$case_capture" \
      CIDER_TEST_NIX_COMMAND="$fake_nix" \
      "$@" \
      /bin/bash "$harness" "$case_system_root" \
      </dev/null >"$case_stdout" 2>"$case_stderr"
    run_status=$?
  else
    /usr/bin/printf '%b' "$input_value" | /usr/bin/env \
      HOME="$case_user_dir" \
      PATH="/usr/bin:/bin" \
      TMPDIR="$case_tmp" \
      CIDER_TEST_NIX_SYSTEM_ROOT="$case_system_root" \
      CIDER_TEST_NIX_CAPTURE="$case_capture" \
      CIDER_TEST_NIX_COMMAND="$fake_nix" \
      "$@" \
      /bin/bash "$harness" "$case_system_root" \
      >"$case_stdout" 2>"$case_stderr"
    run_status=$?
  fi

  run_stdout="$(/bin/cat "$case_stdout")"
  run_stderr="$(/bin/cat "$case_stderr")"
  run_output="$run_stdout$run_stderr"
  run_capture="$(/bin/cat "$case_capture" 2>/dev/null || true)"
}

assert_stage_clean() {
  local label="$1"
  local -a remaining

  remaining=("$case_tmp"/*(N))
  assert_equal 0 "${#remaining}" "$label cleans temporary package state"
}

assert_decline() {
  local name="$1"
  local input_mode="$2"
  local input_value="$3"

  prepare_case "$name"
  run_setup "$input_mode" "$input_value"
  assert_equal 0 "$run_status" "$name declines successfully"
  assert_contains "$run_output" 'creates /nix' \
    "$name explains the Nix store"
  assert_contains "$run_output" 'system daemon' \
    "$name explains the daemon"
  assert_contains "$run_output" 'administrator authorization' \
    "$name explains privilege requirements"
  assert_contains "$run_output" 'Install Determinate Nix now? [y/N]' \
    "$name displays the default-no prompt"
  assert_not_contains "$run_capture" 'STEP=curl' \
    "$name does not download"
  assert_not_contains "$run_capture" 'STEP=sudo' \
    "$name does not invoke sudo"
}

assert_successful_install() {
  local name="$1"
  local answer="$2"

  prepare_case "$name"
  run_setup input "$answer"
  assert_equal 0 "$run_status" "$name installs successfully"
  assert_contains "$run_capture" 'STEP=curl' "$name downloads the package"
  assert_contains "$run_capture" 'ARG=--proto' \
    "$name restricts the download protocol"
  assert_contains "$run_capture" 'ARG==https' \
    "$name allows only HTTPS"
  assert_contains "$run_capture" $'ARG=--proto-redir\nARG==https' \
    "$name restricts redirects to HTTPS"
  assert_contains "$run_capture" 'ARG=--tlsv1.2' \
    "$name requires TLS 1.2 or newer"
  assert_contains "$run_capture" \
    'ARG=https://install.determinate.systems/determinate-pkg/stable/Universal' \
    "$name uses the stable Universal package"
  assert_contains "$run_capture" 'STAGE_MODE=700' \
    "$name uses private temporary storage"
  assert_contains "$run_capture" 'STEP=spctl' \
    "$name assesses package provenance"
  assert_contains "$run_capture" 'STEP=sudo' \
    "$name invokes sudo after assessment"
  assert_contains "$run_capture" 'STEP=system-installer' \
    "$name invokes the system installer"
  assert_contains "$run_capture" $'STEP=nix\nARG=--version' \
    "$name verifies the installed Nix version"
  assert_contains "$run_capture" $'STEP=nix\nARG=flake\nARG=--help' \
    "$name verifies flake support"
  assert_contains "$run_capture" "HARNESS_NIX=$case_system_root/nix/var/nix/profiles/default/bin/nix" \
    "$name keeps the activated profile in its caller"
  assert_contains "$run_output" 'Determinate Nix installed and verified' \
    "$name reports verified installation"
  assert_stage_clean "$name"
}

assert_approved_failure() {
  local name="$1"
  shift

  prepare_case "$name"
  run_setup input 'yes\n' "$@"
  if (( run_status == 0 )); then
    print -u2 "FAIL: $name returned success"
    (( failures += 1 ))
  fi
  assert_stage_clean "$name"
}

# Existing Nix is preserved and suppresses every installation side effect.
prepare_case existing_nix
case_bin="$case_dir/bin"
/bin/mkdir -p "$case_bin"
/bin/ln -s "$fake_nix" "$case_bin/nix"
run_setup eof '' PATH="$case_bin:/usr/bin:/bin"
assert_equal 0 "$run_status" 'existing Nix succeeds'
assert_contains "$run_output" 'nix (Determinate Nix 3.8.1) 2.30.1' \
  'existing Nix version is reported'
assert_not_contains "$run_output" 'Install Determinate Nix now?' \
  'existing Nix is prompt-free'
assert_not_contains "$run_capture" 'STEP=curl' \
  'existing Nix does not download'
assert_not_contains "$run_capture" 'STEP=sudo' \
  'existing Nix does not invoke sudo'

prepare_case existing_nix_empty_version
case_bin="$case_dir/bin"
/bin/mkdir -p "$case_bin"
/bin/ln -s "$fake_nix" "$case_bin/nix"
run_setup eof '' \
  PATH="$case_bin:/usr/bin:/bin" \
  CIDER_TEST_NIX_VERSION_EMPTY=1
if (( run_status == 0 )); then
  print -u2 'FAIL: existing Nix with an empty version returned success'
  (( failures += 1 ))
fi
assert_not_contains "$run_output" 'Install Determinate Nix now?' \
  'invalid existing Nix does not fall through to installation'
assert_not_contains "$run_capture" 'STEP=curl' \
  'invalid existing Nix does not download'

# Every default-no path is safe and non-blocking.
assert_decline lower_no input 'n\n'
assert_decline upper_no input 'NO\n'
assert_decline empty_response input '\n'
assert_decline input_eof eof ''

# Invalid input retries, and accepted yes values are case-insensitive.
prepare_case invalid_then_yes
run_setup input 'maybe\nYeS\n'
assert_equal 0 "$run_status" 'valid yes after invalid input succeeds'
assert_contains "$run_output" 'Please answer yes or no.' \
  'invalid input is rejected visibly'
assert_contains "$run_capture" 'STEP=system-installer' \
  'retry accepts a later yes response'
assert_stage_clean 'invalid then yes'

assert_successful_install short_yes 'Y\n'
assert_successful_install full_yes 'YES\n'

# A later run with the installed profile on PATH is prompt-free and idempotent.
profile_bin="$case_system_root/nix/var/nix/profiles/default/bin"
curl_count_before="$(/usr/bin/grep -c '^STEP=curl$' "$case_capture")"
run_setup eof '' PATH="$profile_bin:/usr/bin:/bin"
curl_count_after="$(/usr/bin/grep -c '^STEP=curl$' "$case_capture")"
assert_equal 0 "$run_status" 'repeat run with Nix succeeds'
assert_equal "$curl_count_before" "$curl_count_after" \
  'repeat run does not redownload Nix'
assert_not_contains "$run_output" 'Install Determinate Nix now?' \
  'repeat run is prompt-free'

# Each approved-install boundary is fatal and cleans its staging directory.
assert_approved_failure curl_failure CIDER_TEST_CURL_EXIT=41
assert_not_contains "$run_capture" 'STEP=spctl' \
  'curl failure stops before assessment'

assert_approved_failure assessment_failure CIDER_TEST_SPCTL_EXIT=42
assert_not_contains "$run_capture" 'STEP=sudo' \
  'assessment failure stops before sudo'

assert_approved_failure wrong_team CIDER_TEST_TEAM_ID=UNAPPROVED123
assert_not_contains "$run_capture" 'STEP=sudo' \
  'wrong Team ID stops before sudo'

assert_approved_failure missing_team CIDER_TEST_TEAM_ID=missing
assert_not_contains "$run_capture" 'STEP=sudo' \
  'missing Team ID stops before sudo'

assert_approved_failure sudo_failure CIDER_TEST_SUDO_EXIT=43
assert_not_contains "$run_capture" 'STEP=system-installer' \
  'sudo failure stops before the system installer'

assert_approved_failure installer_failure CIDER_TEST_INSTALLER_EXIT=44
assert_contains "$run_capture" 'STEP=system-installer' \
  'installer failure reaches only the assessed package'

assert_approved_failure activation_failure CIDER_TEST_PROFILE_MODE=missing
assert_not_contains "$run_capture" 'STEP=nix' \
  'missing profile stops before Nix verification'

assert_approved_failure version_failure CIDER_TEST_NIX_VERSION_EXIT=45
assert_not_contains "$run_capture" $'STEP=nix\nARG=flake' \
  'version failure stops before flakes verification'

assert_approved_failure empty_version_failure CIDER_TEST_NIX_VERSION_EMPTY=1
assert_not_contains "$run_capture" $'STEP=nix\nARG=flake' \
  'empty version output stops before flakes verification'

assert_approved_failure flakes_failure CIDER_TEST_NIX_FLAKE_EXIT=46
assert_contains "$run_capture" $'STEP=nix\nARG=flake\nARG=--help' \
  'flakes failure exercises the final verification boundary'

if (( failures > 0 )); then
  print -u2 "FAIL: $failures Nix setup assertion(s) failed"
  exit 1
fi

print 'PASS: interactive Determinate Nix setup behavior'

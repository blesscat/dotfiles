#!/bin/zsh

set -u
unsetopt BG_NICE

readonly test_dir="${0:A:h}"
readonly module_dir="${test_dir:h}"
readonly repo_dir="${module_dir:h}"
readonly bootstrap="$repo_dir/macos.sh"
readonly setup_fixture="$test_dir/fixtures/bootstrap-setup.sh"
readonly brew_fixture="$test_dir/fixtures/bootstrap-brew.zsh"
readonly installer_fixture="$test_dir/fixtures/bootstrap-installer.zsh"
readonly yazelix_fixture="$test_dir/fixtures/bootstrap-yazelix.zsh"
readonly tmp_dir="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$tmp_dir"' EXIT HUP INT TERM

typeset -i failures=0

if ! /usr/bin/jq -e 'keys == ["symlinks"]' "$repo_dir/bootstrap.json" >/dev/null; then
  print -u2 'FAIL: bootstrap.json must retain only generic symlink metadata'
  exit 1
fi

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

run_bootstrap() {
  local case_dir="$1"
  local path_value="$2"
  local candidates="$3"
  shift 3

  (
    cd "$case_dir" || exit 99
    /usr/bin/env \
      HOME="$case_dir/home" \
      PATH="$path_value" \
      CODEX_TEST_BOOTSTRAP_CAPTURE="$case_dir/steps" \
      CIDER_NIX_SETUP_SCRIPT="$case_dir/forbidden-nix-override" \
      CIDER_NIX_SYSTEM_ROOT="$case_dir/forbidden-system-root" \
      CIDER_BREW_SETUP_SCRIPT="$setup_fixture" \
      CIDER_BREW_CANDIDATES="$candidates" \
      CIDER_CODEX_NOTIFY_INSTALLER="$installer_fixture" \
      CIDER_YAZELIX_INSTALLER="$yazelix_fixture" \
      CIDER_SYMLINK_RUNNER="$case_dir/forbidden-symlinks" \
      "$@" \
        /bin/bash "$bootstrap" \
        > "$case_dir/stdout" 2> "$case_dir/stderr"
  )
}

prepare_case() {
  local name="$1"

  case_dir="$tmp_dir/$name"
  case_bin="$case_dir/bin"
  case_candidate_dir="$case_dir/candidate"
  case_candidate_brew="$case_candidate_dir/brew"
  /bin/mkdir -p "$case_bin" "$case_candidate_dir" "$case_dir/home"
  /bin/ln -s "$test_dir/fixtures/bootstrap-nix.sh" "$case_bin/nix"
}

# A brew already on PATH runs setup, the exact Brewfile bundle command, then
# one notification installer call. Running again repeats the convergent
# orchestration once without invoking legacy per-package readers.
prepare_case path_brew
/bin/ln -s "$brew_fixture" "$case_bin/brew"
run_bootstrap "$case_dir" "$case_bin:/usr/bin:/bin" \
  "$case_dir/missing-apple:$case_dir/missing-intel" \
  CODEX_TEST_NIX_EXPORT=1
path_status=$?
assert_equal 0 "$path_status" 'bootstrap with brew on PATH succeeds'
path_stdout="$(/bin/cat "$case_dir/stdout")"
assert_contains "$path_stdout" \
  'macos bootstrap: running notification installer:' \
  'bootstrap labels notification setup before its output'
assert_contains "$path_stdout" \
  'macos bootstrap: running Yazelix installer:' \
  'bootstrap labels Yazelix setup before its output'
expected_path_steps="$(/usr/bin/printf '%s\n' \
  'STEP=nix' \
  'END' \
  'STEP=setup' \
  'END' \
  'STEP=brew' \
  'ARG=bundle' \
  'ARG=install' \
  "ARG=--file=$repo_dir/Brewfile" \
  'ARG=--no-upgrade' \
  'END' \
  'STEP=installer' \
  'END' \
  'STEP=yazelix' \
  'END')"
assert_equal "$expected_path_steps" "$(/bin/cat "$case_dir/steps")" \
  'bootstrap records setup, bundle, and installer in order'

run_bootstrap "$case_dir" "$case_bin:/usr/bin:/bin" \
  "$case_dir/missing-apple:$case_dir/missing-intel" \
  CODEX_TEST_NIX_EXPORT=1
path_second_status=$?
assert_equal 0 "$path_second_status" 'second bootstrap fixture run succeeds'
assert_equal 2 \
  "$(/usr/bin/grep -c '^STEP=installer$' "$case_dir/steps")" \
  'each bootstrap run invokes the installer exactly once'
assert_equal 2 \
  "$(/usr/bin/grep -c '^ARG=--no-upgrade$' "$case_dir/steps")" \
  'each bootstrap run preserves --no-upgrade'

# If brew was absent from PATH, discovery through a standard-location fixture
# applies shellenv before bundle and installer execution.
prepare_case discovered_brew
/bin/ln -s "$brew_fixture" "$case_candidate_brew"
run_bootstrap "$case_dir" "$case_bin:/usr/bin:/bin" \
  "$case_candidate_brew:$case_dir/missing-intel" \
  CODEX_TEST_REQUIRE_SHELLENV=1
discovered_status=$?
assert_equal 0 "$discovered_status" \
  'bootstrap discovers brew after setup'
expected_discovered_steps="$(/usr/bin/printf '%s\n' \
  'STEP=nix' \
  'END' \
  'STEP=setup' \
  'END' \
  'STEP=brew' \
  'ARG=shellenv' \
  'END' \
  'STEP=brew' \
  'ARG=bundle' \
  'ARG=install' \
  "ARG=--file=$repo_dir/Brewfile" \
  'ARG=--no-upgrade' \
  'END' \
  'STEP=installer' \
  'END' \
  'STEP=yazelix' \
  'END')"
assert_equal "$expected_discovered_steps" "$(/bin/cat "$case_dir/steps")" \
  'discovered brew applies shellenv before bundle'

# Nix setup is the first executable stage, and an accepted-install failure
# prevents Homebrew or every later installer from running.
prepare_case nix_failure
/bin/ln -s "$brew_fixture" "$case_bin/brew"
run_bootstrap "$case_dir" "$case_bin:/usr/bin:/bin" \
  "$case_dir/missing-apple:$case_dir/missing-intel" \
  CODEX_TEST_NIX_EXIT=31
nix_failure_status=$?
assert_equal 1 "$nix_failure_status" \
  'failed Nix setup propagates its status'
assert_equal $'STEP=nix\nEND' "$(/bin/cat "$case_dir/steps")" \
  'failed Nix setup stops before Homebrew'

# An unavailable brew or failed bundle is fatal and never reaches installer.
prepare_case missing_brew
run_bootstrap "$case_dir" "$case_bin:/usr/bin:/bin" \
  "$case_dir/missing-apple:$case_dir/missing-intel"
missing_status=$?
if (( missing_status == 0 )); then
  print -u2 'FAIL: missing Homebrew returns success'
  (( failures += 1 ))
fi
assert_equal 0 \
  "$(/usr/bin/grep -c '^STEP=installer$' "$case_dir/steps")" \
  'missing Homebrew skips installer'
assert_equal 0 \
  "$(/usr/bin/grep -c '^STEP=yazelix$' "$case_dir/steps")" \
  'missing Homebrew skips Yazelix setup'

prepare_case bundle_failure
/bin/ln -s "$brew_fixture" "$case_bin/brew"
run_bootstrap "$case_dir" "$case_bin:/usr/bin:/bin" \
  "$case_dir/missing-apple:$case_dir/missing-intel" \
  CODEX_TEST_BUNDLE_EXIT=17
bundle_failure_status=$?
if (( bundle_failure_status == 0 )); then
  print -u2 'FAIL: failed brew bundle returns success'
  (( failures += 1 ))
fi
assert_equal 0 \
  "$(/usr/bin/grep -c '^STEP=installer$' "$case_dir/steps")" \
  'failed bundle skips installer'
assert_equal 0 \
  "$(/usr/bin/grep -c '^STEP=yazelix$' "$case_dir/steps")" \
  'failed bundle skips Yazelix setup'
assert_contains "$(/bin/cat "$case_dir/steps")" 'ARG=--no-upgrade' \
  'failed bundle still used the required no-upgrade argv'

prepare_case installer_failure
/bin/ln -s "$brew_fixture" "$case_bin/brew"
run_bootstrap "$case_dir" "$case_bin:/usr/bin:/bin" \
  "$case_dir/missing-apple:$case_dir/missing-intel" \
  CODEX_TEST_INSTALLER_EXIT=19
installer_failure_status=$?
assert_equal 19 "$installer_failure_status" \
  'failed notification installer propagates its status'
assert_equal 0 \
  "$(/usr/bin/grep -c '^STEP=yazelix$' "$case_dir/steps")" \
  'failed notification installer skips Yazelix setup'

prepare_case yazelix_failure
/bin/ln -s "$brew_fixture" "$case_bin/brew"
run_bootstrap "$case_dir" "$case_bin:/usr/bin:/bin" \
  "$case_dir/missing-apple:$case_dir/missing-intel" \
  CODEX_TEST_YAZELIX_EXIT=29
yazelix_failure_status=$?
assert_equal 29 "$yazelix_failure_status" \
  'failed Yazelix setup propagates its status'
assert_equal 1 \
  "$(/usr/bin/grep -c '^STEP=yazelix$' "$case_dir/steps")" \
  'bootstrap reaches Yazelix setup after prior steps succeed'

for forbidden in \
  "$tmp_dir"/*/forbidden-symlinks(N); do
  if [[ -e "$forbidden" ]]; then
    print -u2 "FAIL: bootstrap invoked a forbidden generic runner: $forbidden"
    (( failures += 1 ))
  fi
done

if (( failures > 0 )); then
  print -u2 "FAIL: $failures bootstrap assertion(s) failed"
  exit 1
fi

print 'PASS: macOS Brewfile bootstrap orchestration'

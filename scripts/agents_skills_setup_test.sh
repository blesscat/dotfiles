#!/usr/bin/env bash

set -uo pipefail

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(cd -- "$test_dir/.." && pwd -P)"
setup_script="$repo_dir/scripts/agents_skills_setup.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

failures=0
case_dir=''
case_home=''
case_source=''
case_stdout=''
case_stderr=''
case_path='/usr/bin:/bin'

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s (expected %q, got %q)\n' "$label" "$expected" "$actual" >&2
    failures=$((failures + 1))
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'FAIL: %s (missing %q)\n' "$label" "$needle" >&2
    failures=$((failures + 1))
  fi
}

assert_path_exists() {
  local path="$1"
  local label="$2"

  if [[ ! -e "$path" && ! -L "$path" ]]; then
    printf 'FAIL: %s (missing %s)\n' "$label" "$path" >&2
    failures=$((failures + 1))
  fi
}

assert_regular_file() {
  local path="$1"
  local label="$2"

  if [[ ! -f "$path" || -L "$path" ]]; then
    printf 'FAIL: %s (not a regular file: %s)\n' "$label" "$path" >&2
    failures=$((failures + 1))
  fi
}

assert_link_target() {
  local path="$1"
  local expected="$2"
  local label="$3"
  local actual=''

  if [[ -L "$path" ]]; then
    actual="$(readlink "$path")"
  fi
  assert_equal "$expected" "$actual" "$label"
}

prepare_case() {
  local name="$1"

  case_dir="$tmp_dir/$name"
  case_home="$case_dir/home"
  case_source="$case_dir/source"
  case_stdout="$case_dir/stdout"
  case_stderr="$case_dir/stderr"
  case_path='/usr/bin:/bin'

  mkdir -p "$case_home" "$case_source/sample-skill"
  printf '%s\n' '# sample skill' > "$case_source/sample-skill/SKILL.md"
}

run_setup() {
  local status=0

  if env \
    HOME="$case_home" \
    CIDER_AGENTS_SKILLS_SOURCE="$case_source" \
    PATH="$case_path" \
    "$setup_script" >"$case_stdout" 2>"$case_stderr"; then
    status=0
  else
    status=$?
  fi
  return "$status"
}

count_backups() {
  local -a backups=("$case_home/.agents"/skills.backup-*)
  local backup
  local count=0

  for backup in "${backups[@]}"; do
    if [[ -e "$backup" || -L "$backup" ]]; then
      count=$((count + 1))
    fi
  done
  printf '%s\n' "$count"
}

backup_path() {
  local -a backups=("$case_home/.agents"/skills.backup-*)
  local backup

  for backup in "${backups[@]}"; do
    if [[ -e "$backup" || -L "$backup" ]]; then
      printf '%s\n' "$backup"
      return 0
    fi
  done
}

# A fresh temporary home gets a link to the fixture source and keeps the skill
# discoverable at its existing user-level path.
prepare_case fresh
if run_setup; then
  fresh_status=0
else
  fresh_status=$?
fi
assert_equal 0 "$fresh_status" 'fresh setup succeeds'
assert_link_target "$case_home/.agents/skills" "$case_source" \
  'fresh setup creates the canonical link'
assert_regular_file "$case_home/.agents/skills/sample-skill/SKILL.md" \
  'fresh setup keeps the skill discoverable'

# The active repository source is also accepted, and the copied OpenSpec skill
# tree remains available without introducing a lock file into the source.
prepare_case repository_source
case_source="$repo_dir/.agents/skills"
if run_setup; then
  repository_status=0
else
  repository_status=$?
fi
assert_equal 0 "$repository_status" 'repository source setup succeeds'
assert_link_target "$case_home/.agents/skills" "$repo_dir/.agents/skills" \
  'repository source is used as canonical link target'
assert_regular_file "$case_home/.agents/skills/openspec-to-main-pr/SKILL.md" \
  'copied OpenSpec skill remains discoverable'
if [[ -e "$repo_dir/.agents/skills/.skill-lock.json" ]]; then
  printf 'FAIL: repository source contains generated lock state\n' >&2
  failures=$((failures + 1))
fi

# Existing local skills are moved to a recoverable backup, while the adjacent
# lock file remains byte-for-byte unchanged.
prepare_case existing_directory
mkdir -p "$case_home/.agents/skills/local-skill"
printf '%s\n' 'local content' > "$case_home/.agents/skills/local-skill/SKILL.md"
printf '%s\n' 'local lock' > "$case_home/.agents/.skill-lock.json"
lock_before="$(<"$case_home/.agents/.skill-lock.json")"
if run_setup; then
  existing_status=0
else
  existing_status=$?
fi
assert_equal 0 "$existing_status" 'existing directory setup succeeds'
existing_backup="$(backup_path)"
assert_path_exists "$existing_backup" 'existing directory gets a backup'
assert_regular_file "$existing_backup/local-skill/SKILL.md" \
  'backup preserves existing skill files'
lock_after="$(<"$case_home/.agents/.skill-lock.json")"
assert_equal "$lock_before" "$lock_after" 'lock file remains unchanged'

# Re-running with the correct link is a no-op and does not create another
# backup.
backup_count_before="$(count_backups)"
if run_setup; then
  noop_status=0
else
  noop_status=$?
fi
backup_count_after="$(count_backups)"
assert_equal 0 "$noop_status" 'correct-link rerun succeeds'
assert_equal "$backup_count_before" "$backup_count_after" \
  'correct-link rerun does not create a backup'
assert_contains "$(<"$case_stdout")" 'already linked to' \
  'correct-link rerun reports a no-op'

# An incorrect link is preserved as a link backup before the canonical link is
# installed.
prepare_case incorrect_link
mkdir -p "$case_dir/other-source" "$case_home/.agents"
ln -s "$case_dir/other-source" "$case_home/.agents/skills"
if run_setup; then
  incorrect_status=0
else
  incorrect_status=$?
fi
incorrect_backup="$(backup_path)"
assert_equal 0 "$incorrect_status" 'incorrect-link setup succeeds'
assert_link_target "$case_home/.agents/skills" "$case_source" \
  'incorrect link is replaced with canonical link'
assert_link_target "$incorrect_backup" "$case_dir/other-source" \
  'incorrect link is retained as a backup'

# Invalid source content fails before the existing installation is moved.
prepare_case invalid_source
case_source="$case_dir/empty-source"
mkdir -p "$case_source"
mkdir -p "$case_home/.agents/skills/current"
printf '%s\n' 'current content' > "$case_home/.agents/skills/current/SKILL.md"
if run_setup; then
  invalid_status=0
else
  invalid_status=$?
fi
if (( invalid_status == 0 )); then
  printf 'FAIL: invalid source unexpectedly succeeded\n' >&2
  failures=$((failures + 1))
fi
assert_regular_file "$case_home/.agents/skills/current/SKILL.md" \
  'invalid source leaves existing installation intact'
if [[ -L "$case_home/.agents/skills" ]]; then
  printf 'FAIL: invalid source replaced the existing directory\n' >&2
  failures=$((failures + 1))
fi
assert_contains "$(<"$case_stderr")" 'contains no skill directories' \
  'invalid source reports the validation failure'

# A link creation failure restores the original directory instead of leaving a
# partially migrated path.
prepare_case activation_failure
mkdir -p "$case_home/.agents/skills/current" "$case_dir/fake-bin"
printf '%s\n' 'current content' > "$case_home/.agents/skills/current/SKILL.md"
printf '%s\n' '#!/usr/bin/env bash' 'exit 42' > "$case_dir/fake-bin/ln"
chmod 755 "$case_dir/fake-bin/ln"
case_path="$case_dir/fake-bin:/usr/bin:/bin"
if run_setup; then
  activation_status=0
else
  activation_status=$?
fi
if (( activation_status == 0 )); then
  printf 'FAIL: simulated link failure unexpectedly succeeded\n' >&2
  failures=$((failures + 1))
fi
assert_regular_file "$case_home/.agents/skills/current/SKILL.md" \
  'link failure restores the original directory'
if [[ -L "$case_home/.agents/skills" ]]; then
  printf 'FAIL: link failure left a symbolic link behind\n' >&2
  failures=$((failures + 1))
fi
assert_equal 0 "$(count_backups)" \
  'restored activation does not leave a duplicate backup'

if (( failures > 0 )); then
  printf 'FAIL: %d agent skill setup assertion(s) failed\n' "$failures" >&2
  exit 1
fi

printf '%s\n' 'PASS: managed agent skill activation'

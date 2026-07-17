#!/bin/zsh

set -u
unsetopt BG_NICE

readonly test_dir="${0:A:h}"
readonly module_dir="${test_dir:h}"
readonly installer="$module_dir/install.zsh"
readonly fake_brew="$test_dir/fixtures/fake-brew.zsh"
readonly fake_codesign="$test_dir/fixtures/fake-codesign.zsh"
readonly fake_codex="$test_dir/fixtures/fake-codex.zsh"

if [[ ! -x "$installer" ]]; then
  print -u2 "FAIL: installer is missing or not executable: $installer"
  exit 1
fi

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

assert_path_absent() {
  local path="$1"
  local label="$2"

  if [[ -e "$path" || -L "$path" ]]; then
    print -u2 "FAIL: $label still exists: $path"
    (( failures += 1 ))
  fi
}

assert_tree_contains() {
  local directory="$1"
  local needle="$2"
  local label="$3"

  if [[ ! -d "$directory" ]] \
      || ! /usr/bin/grep -R -Fq -- "$needle" "$directory"; then
    print -u2 "FAIL: $label (missing '$needle' under '$directory')"
    (( failures += 1 ))
  fi
}

assert_link_target() {
  local link="$1"
  local expected="$2"
  local label="$3"
  local actual=''

  if [[ -L "$link" ]]; then
    actual="$(/usr/bin/readlink "$link")"
  fi
  assert_equal "$expected" "$actual" "$label"
  if [[ ! -x "$link" ]]; then
    print -u2 "FAIL: $label is not executable"
    (( failures += 1 ))
  fi
}

assert_regular_file() {
  local path="$1"
  local label="$2"

  if [[ ! -f "$path" || -L "$path" ]]; then
    print -u2 "FAIL: $label is not a regular file: $path"
    (( failures += 1 ))
  fi
}

assert_mode() {
  local expected="$1"
  local path="$2"
  local label="$3"
  local actual=''

  if [[ -e "$path" || -L "$path" ]]; then
    actual="$(/usr/bin/stat -f '%Lp' "$path")"
  fi
  assert_equal "$expected" "$actual" "$label"
}

assert_no_staging_paths() {
  local parent="$1"
  local label="$2"
  local matches

  matches=("$parent"/.terminal-notifier.app.stage-*(N))
  if (( $#matches != 0 )); then
    print -u2 "FAIL: $label left staging paths: $matches"
    (( failures += 1 ))
  fi
}

count_backup_runs() {
  local state_home="$1"
  local backup_root="$state_home/cider/backups/codex-notify"
  local runs

  runs=("$backup_root"/*(N/))
  /usr/bin/printf '%s\n' "$#runs"
}

latest_backup_run() {
  local state_home="$1"
  local backup_root="$state_home/cider/backups/codex-notify"
  local runs

  runs=("$backup_root"/*(N/om))
  if (( $#runs > 0 )); then
    /usr/bin/printf '%s\n' "$runs[1]"
  fi
}

prepare_case() {
  local name="$1"

  case_dir="$tmp_dir/$name"
  case_home="$case_dir/home"
  case_codex_home="$case_dir/codex-home"
  case_state_home="$case_dir/state"
  case_prefix="$case_dir/formula-prefix"
  case_app_source="$case_prefix/terminal-notifier.app"
  case_brew_capture="$case_dir/brew.args"
  case_codesign_capture="$case_dir/codesign.args"
  case_codex_capture="$case_dir/codex.args"
  case_stdout="$case_dir/install.stdout"
  case_stderr="$case_dir/install.stderr"

  /bin/mkdir -p \
    "$case_home" \
    "$case_codex_home" \
    "$case_state_home" \
    "$case_app_source/Contents/MacOS"
  /usr/bin/printf 'source-app-%s\n' "$name" \
    > "$case_app_source/Contents/Info.plist"
  /usr/bin/printf '%s\n' '#!/bin/zsh' 'exit 0' \
    > "$case_app_source/Contents/MacOS/terminal-notifier"
  /bin/chmod 755 "$case_app_source/Contents/MacOS/terminal-notifier"
}

run_installer() {
  /usr/bin/env \
    HOME="$case_home" \
    CODEX_HOME="$case_codex_home" \
    XDG_STATE_HOME="$case_state_home" \
    PATH="/usr/bin:/bin" \
    CODEX_NOTIFY_BREW="$fake_brew" \
    CODEX_NOTIFY_CODESIGN="$fake_codesign" \
    CODEX_NOTIFY_CODEX="$fake_codex" \
    CODEX_TEST_BREW_PREFIX="$case_prefix" \
    CODEX_TEST_BREW_CAPTURE="$case_brew_capture" \
    CODEX_TEST_CODESIGN_CAPTURE="$case_codesign_capture" \
    CODEX_TEST_CODEX_CAPTURE="$case_codex_capture" \
    CODEX_TEST_REAL_CODEX_HOME="$case_codex_home" \
    CODEX_TEST_CODEX_REQUIRE='notify = [' \
    "$@" \
      "$installer" > "$case_stdout" 2> "$case_stderr"
}

run_rollback() {
  local selected_run="$1"

  /usr/bin/env \
    HOME="$case_home" \
    CODEX_HOME="$case_codex_home" \
    XDG_STATE_HOME="$case_state_home" \
    PATH="/usr/bin:/bin" \
      "$installer" --rollback "$selected_run" \
      > "$case_stdout" 2> "$case_stderr"
}

make_sky_available() {
  case_sky="$case_codex_home/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
  /bin/mkdir -p "${case_sky:h}"
  /usr/bin/printf '%s\n' '#!/bin/zsh' 'exit 0' > "$case_sky"
  /bin/chmod 755 "$case_sky"
}

readonly target_names=(
  codex-notify
  codex-permission-notify
  codex-notification-route
)

# Clean install discovers the formula prefix, activates a verified app, and
# creates executable links while deferring unavailable Codex/Sky activation.
prepare_case clean
run_installer
clean_status=$?

assert_equal 0 "$clean_status" 'clean installer run succeeds'
for target_name in "$target_names[@]"; do
  assert_link_target \
    "$case_home/.local/bin/$target_name" \
    "$module_dir/bin/$target_name" \
    "clean install links $target_name to the module"
done
assert_file_contains \
  "$case_home/.local/share/codex-notify/terminal-notifier.app/Contents/Info.plist" \
  'source-app-clean' \
  'clean install copies the Homebrew app'
assert_file_contains "$case_brew_capture" 'ARG=--prefix' \
  'installer asks Homebrew for a formula prefix'
assert_file_contains "$case_brew_capture" 'ARG=terminal-notifier' \
  'installer resolves terminal-notifier specifically'
assert_file_contains "$case_codesign_capture" 'ARG=--sign' \
  'installer ad-hoc signs the staged app'
assert_file_contains "$case_codesign_capture" 'ARG=--verify' \
  'installer verifies the staged app'
assert_file_contains "$case_codesign_capture" 'ARG=--deep' \
  'installer applies deep signature checks'
assert_file_contains "$case_codesign_capture" 'ARG=--strict' \
  'installer applies strict signature checks'
assert_contains "$(/bin/cat "$case_stdout")" 'deferred' \
  'clean install reports deferred Codex activation'
assert_contains "$(/bin/cat "$case_stdout")" 'install.zsh' \
  'deferred install prints the rerun command'

clean_backup_count="$(count_backup_runs "$case_state_home")"
run_installer
clean_second_status=$?
assert_equal 0 "$clean_second_status" 'already-current installer rerun succeeds'
assert_equal "$clean_backup_count" "$(count_backup_runs "$case_state_home")" \
  'already-current rerun creates no needless backup'

# Byte-identical app contents are not enough for a no-op: an invalid active
# signature must force a replacement from the independently verified stage.
prepare_case invalid_active_signature
run_installer
invalid_active_first_status=$?
assert_equal 0 "$invalid_active_first_status" \
  'active signature fixture installs initially'
invalid_active_backup_count="$(count_backup_runs "$case_state_home")"
invalid_active_app="$case_home/.local/share/codex-notify/terminal-notifier.app"
run_installer CODEX_TEST_CODESIGN_INVALID_PATH="$invalid_active_app"
invalid_active_second_status=$?
assert_equal 0 "$invalid_active_second_status" \
  'invalid active signature is repaired successfully'
assert_equal "$(( invalid_active_backup_count + 1 ))" \
  "$(count_backup_runs "$case_state_home")" \
  'invalid active signature creates a replacement backup'
invalid_active_backup="$(latest_backup_run "$case_state_home")"
assert_file_contains "$invalid_active_backup/manifest.tsv" \
  $'app\t'"$invalid_active_app" \
  'invalid active signature records the replaced app'

# Standalone scripts and a previous app are grouped into one backup run.
prepare_case migration
/bin/mkdir -p \
  "$case_home/.local/bin" \
  "$case_home/.local/share/codex-notify/terminal-notifier.app/Contents"
for target_name in "$target_names[@]"; do
  /usr/bin/printf 'old-%s\n' "$target_name" \
    > "$case_home/.local/bin/$target_name"
  /bin/chmod 755 "$case_home/.local/bin/$target_name"
done
/usr/bin/printf 'old-active-app\n' \
  > "$case_home/.local/share/codex-notify/terminal-notifier.app/Contents/Info.plist"

run_installer
migration_status=$?
assert_equal 0 "$migration_status" 'standalone migration succeeds'
for target_name in "$target_names[@]"; do
  assert_link_target \
    "$case_home/.local/bin/$target_name" \
    "$module_dir/bin/$target_name" \
    "migration replaces $target_name with the module link"
done
assert_equal 1 "$(count_backup_runs "$case_state_home")" \
  'migration groups changes into one backup run'
migration_backup_root="$case_state_home/cider/backups/codex-notify"
for target_name in "$target_names[@]"; do
  assert_tree_contains "$migration_backup_root" "old-$target_name" \
    "migration backs up $target_name"
done
assert_tree_contains "$migration_backup_root" 'old-active-app' \
  'migration backs up the previous app'
migration_backup="$(latest_backup_run "$case_state_home")"
run_rollback "$migration_backup"
migration_rollback_status=$?
assert_equal 0 "$migration_rollback_status" \
  'migration backup rollback succeeds'
for target_name in "$target_names[@]"; do
  assert_regular_file "$case_home/.local/bin/$target_name" \
    "migration rollback restores $target_name as a regular file"
  assert_file_contains "$case_home/.local/bin/$target_name" \
    "old-$target_name" \
    "migration rollback restores $target_name content"
done
assert_file_contains \
  "$case_home/.local/share/codex-notify/terminal-notifier.app/Contents/Info.plist" \
  'old-active-app' \
  'migration rollback restores the previous app'

# Rollback treats its manifest as a strict installer-owned format. A bad
# version or noncanonical backup path must be rejected before active targets
# change.
prepare_case rollback_bad_version
run_installer
bad_version_backup="$(latest_backup_run "$case_state_home")"
/usr/bin/awk '
  BEGIN { OFS = "\t" }
  NR == 1 { print "version", "999"; next }
  { print }
' "$bad_version_backup/manifest.tsv" \
  > "$bad_version_backup/manifest.tsv.edited"
/bin/mv \
  "$bad_version_backup/manifest.tsv.edited" \
  "$bad_version_backup/manifest.tsv"
run_rollback "$bad_version_backup"
bad_version_status=$?
if (( bad_version_status == 0 )); then
  print -u2 'FAIL: rollback with a bad manifest version returns success'
  (( failures += 1 ))
fi
assert_contains "$(/bin/cat "$case_stderr")" 'version 2 header' \
  'rollback explains the required manifest version'
assert_link_target \
  "$case_home/.local/bin/codex-notify" \
  "$module_dir/bin/codex-notify" \
  'bad manifest version leaves installed targets active'

prepare_case rollback_bad_relative
run_installer
bad_relative_backup="$(latest_backup_run "$case_state_home")"
/usr/bin/awk '
  BEGIN { FS = OFS = "\t" }
  NR == 2 { $4 = "../outside-backup" }
  { print }
' "$bad_relative_backup/manifest.tsv" \
  > "$bad_relative_backup/manifest.tsv.edited"
/bin/mv \
  "$bad_relative_backup/manifest.tsv.edited" \
  "$bad_relative_backup/manifest.tsv"
run_rollback "$bad_relative_backup"
bad_relative_status=$?
if (( bad_relative_status == 0 )); then
  print -u2 'FAIL: rollback with a noncanonical backup path returns success'
  (( failures += 1 ))
fi
assert_contains "$(/bin/cat "$case_stderr")" 'canonical backup path' \
  'rollback explains the fixed target backup mapping'
assert_link_target \
  "$case_home/.local/bin/codex-notify" \
  "$module_dir/bin/codex-notify" \
  'noncanonical backup path leaves installed targets active'

# Even the canonical relative path is unsafe if an intermediate backup
# directory has been replaced by a symlink outside the selected run.
prepare_case rollback_symlink_parent
/bin/mkdir -p "$case_home/.local/bin"
/usr/bin/printf 'old-before-symlink-parent\n' \
  > "$case_home/.local/bin/codex-notify"
/bin/chmod 755 "$case_home/.local/bin/codex-notify"
run_installer
symlink_parent_backup="$(latest_backup_run "$case_state_home")"
symlink_parent_outside="$case_dir/outside-backup"
/bin/mkdir -p "$symlink_parent_outside"
/usr/bin/printf 'outside-tampered-backup\n' \
  > "$symlink_parent_outside/codex-notify"
/bin/chmod 755 "$symlink_parent_outside/codex-notify"
/bin/rm -rf "$symlink_parent_backup/targets/local-bin"
/bin/ln -s \
  "$symlink_parent_outside" \
  "$symlink_parent_backup/targets/local-bin"
run_rollback "$symlink_parent_backup"
symlink_parent_status=$?
if (( symlink_parent_status == 0 )); then
  print -u2 'FAIL: rollback through a symlinked backup parent returns success'
  (( failures += 1 ))
fi
assert_contains "$(/bin/cat "$case_stderr")" 'escapes the selected run' \
  'rollback explains an escaping backup parent'
assert_link_target \
  "$case_home/.local/bin/codex-notify" \
  "$module_dir/bin/codex-notify" \
  'symlinked backup parent leaves installed targets active'

# Failed verification and a missing formula app both leave every prior target
# active and remove staging directories.
prepare_case signature_failure
/bin/mkdir -p \
  "$case_home/.local/bin" \
  "$case_home/.local/share/codex-notify/terminal-notifier.app/Contents"
for target_name in "$target_names[@]"; do
  /usr/bin/printf 'keep-%s\n' "$target_name" \
    > "$case_home/.local/bin/$target_name"
  /bin/chmod 755 "$case_home/.local/bin/$target_name"
done
/usr/bin/printf 'keep-active-app\n' \
  > "$case_home/.local/share/codex-notify/terminal-notifier.app/Contents/Info.plist"

run_installer CODEX_TEST_CODESIGN_VERIFY_EXIT=1
signature_failure_status=$?
if (( signature_failure_status == 0 )); then
  print -u2 'FAIL: signature verification failure returns success'
  (( failures += 1 ))
fi
for target_name in "$target_names[@]"; do
  assert_regular_file "$case_home/.local/bin/$target_name" \
    "signature failure preserves $target_name"
  assert_file_contains "$case_home/.local/bin/$target_name" \
    "keep-$target_name" \
    "signature failure preserves $target_name content"
done
assert_file_contains \
  "$case_home/.local/share/codex-notify/terminal-notifier.app/Contents/Info.plist" \
  'keep-active-app' \
  'signature failure preserves the active app'
assert_no_staging_paths "$case_home/.local/share/codex-notify" \
  'signature failure'

prepare_case copy_failure
/bin/mkdir -p "$case_home/.local/bin"
/usr/bin/printf 'keep-copy-failure\n' \
  > "$case_home/.local/bin/codex-notify"
/bin/rm -rf "$case_app_source"
run_installer
copy_failure_status=$?
if (( copy_failure_status == 0 )); then
  print -u2 'FAIL: missing formula app returns success'
  (( failures += 1 ))
fi
assert_regular_file "$case_home/.local/bin/codex-notify" \
  'copy failure preserves the previous script'
assert_file_contains "$case_home/.local/bin/codex-notify" \
  'keep-copy-failure' \
  'copy failure preserves previous script content'
assert_no_staging_paths "$case_home/.local/share/codex-notify" \
  'copy failure'

prepare_case missing_brew
run_installer CODEX_NOTIFY_BREW="$case_dir/missing-brew"
missing_brew_status=$?
if (( missing_brew_status == 0 )); then
  print -u2 'FAIL: missing Homebrew returns success'
  (( failures += 1 ))
fi
if [[ -e "$case_home/.local/bin/codex-notify" ]]; then
  print -u2 'FAIL: missing Homebrew mutates runtime targets'
  (( failures += 1 ))
fi

# Ready prerequisites activate only the owned TOML and hook entries while
# preserving unrelated user state. All changed targets share one backup run.
prepare_case ready_merge
make_sky_available
/usr/bin/printf '%s\n' \
  '# keep this top-level comment' \
  'model = "gpt-portable"' \
  'notify = ["old-notifier"]' \
  '' \
  '[tui]' \
  'animations = true' \
  'notifications = true' \
  '' \
  '[projects."/portable/project"]' \
  'trust_level = "trusted"' \
  '' \
  '[mcp_servers.demo]' \
  'command = "/tmp/keep-mcp"' \
  > "$case_codex_home/config.toml"
/usr/bin/printf '%s\n' \
  '{' \
  '  "metadata": {"keep": "yes"},' \
  '  "hooks": {' \
  '    "PermissionRequest": [' \
  '      {' \
  '        "matcher": "keep",' \
  '        "hooks": [' \
  '          {"type": "command", "command": "/tmp/keep-handler", "timeout": 20},' \
  '          {"type": "command", "command": "/legacy/a/codex-permission-notify", "timeout": 4}' \
  '        ]' \
  '      },' \
  '      {' \
  '        "matcher": "*",' \
  '        "hooks": [' \
  '          {"type": "command", "command": "/legacy/b/codex-permission-notify", "timeout": 5}' \
  '        ]' \
  '      }' \
  '    ],' \
  '    "PostToolUse": [' \
  '      {"matcher": "*", "hooks": [' \
  '        {"type": "command", "command": "/tmp/post-handler", "timeout": 1}' \
  '      ]}' \
  '    ]' \
  '  }' \
  '}' \
  > "$case_codex_home/hooks.json"
/bin/chmod 600 \
  "$case_codex_home/config.toml" \
  "$case_codex_home/hooks.json"

run_installer
ready_status=$?
assert_equal 0 "$ready_status" 'ready installer run succeeds'
assert_file_contains "$case_codex_home/config.toml" \
  '# keep this top-level comment' \
  'config merge preserves top-level comments'
assert_file_contains "$case_codex_home/config.toml" \
  'model = "gpt-portable"' \
  'config merge preserves model settings'
assert_file_contains "$case_codex_home/config.toml" \
  '[projects."/portable/project"]' \
  'config merge preserves project state'
assert_file_contains "$case_codex_home/config.toml" \
  'command = "/tmp/keep-mcp"' \
  'config merge preserves MCP settings'
assert_file_contains "$case_codex_home/config.toml" \
  "$case_sky" \
  'config merge installs the current Sky path'
assert_file_contains "$case_codex_home/config.toml" \
  "$case_home/.local/bin/codex-notify" \
  'config merge installs the current wrapper path'
assert_file_contains "$case_codex_home/config.toml" '"[\"' \
  'config merge preserves nested previous-notify JSON escaping'
assert_file_contains "$case_codex_home/config.toml" \
  'notifications = false' \
  'config merge disables built-in TUI notifications'
assert_equal 1 \
  "$(/usr/bin/grep -Ec '^[[:space:]]*notify[[:space:]]*=' "$case_codex_home/config.toml")" \
  'config merge leaves exactly one top-level notify'
assert_equal 1 \
  "$(/usr/bin/grep -Ec '^[[:space:]]*notifications[[:space:]]*=' "$case_codex_home/config.toml")" \
  'config merge leaves exactly one TUI notifications value'

owned_hook_count="$(/usr/bin/jq \
  '[.hooks.PermissionRequest[]?.hooks[]?
    | select(.type == "command"
      and (.command | type == "string")
      and (.command | endswith("/codex-permission-notify")))]
   | length' "$case_codex_home/hooks.json")"
assert_equal 1 "$owned_hook_count" \
  'hook merge converges duplicate owned handlers'
canonical_hook_command="$(/usr/bin/jq -r \
  '[.hooks.PermissionRequest[]?.hooks[]?
    | select(.command | type == "string")
    | select(.command | endswith("/codex-permission-notify"))][0].command' \
  "$case_codex_home/hooks.json")"
assert_equal "$case_home/.local/bin/codex-permission-notify" \
  "$canonical_hook_command" \
  'hook merge installs the canonical permission adapter'
canonical_hook_timeout="$(/usr/bin/jq -r \
  '[.hooks.PermissionRequest[]?.hooks[]?
    | select(.command | type == "string")
    | select(.command | endswith("/codex-permission-notify"))][0].timeout' \
  "$case_codex_home/hooks.json")"
assert_equal 10 "$canonical_hook_timeout" \
  'hook merge installs the canonical timeout'
assert_equal 'yes' \
  "$(/usr/bin/jq -r '.metadata.keep' "$case_codex_home/hooks.json")" \
  'hook merge preserves unrelated top-level JSON'
assert_equal 1 \
  "$(/usr/bin/jq \
    '[.hooks.PermissionRequest[]?.hooks[]?
      | select(.command == "/tmp/keep-handler")] | length' \
    "$case_codex_home/hooks.json")" \
  'hook merge preserves unrelated permission handlers'
assert_equal 1 \
  "$(/usr/bin/jq \
    '[.hooks.PostToolUse[]?.hooks[]?
      | select(.command == "/tmp/post-handler")] | length' \
    "$case_codex_home/hooks.json")" \
  'hook merge preserves unrelated hook events'
assert_file_not_contains "$case_codex_home/hooks.json" 'trust' \
  'hook merge does not synthesize trust state'
assert_file_not_contains "$case_codex_home/hooks.json" 'hash' \
  'hook merge does not synthesize trust hashes'
assert_mode 600 "$case_codex_home/config.toml" \
  'config activation retains a private mode'
assert_mode 600 "$case_codex_home/hooks.json" \
  'hook activation retains a private mode'
assert_file_contains "$case_codex_capture" 'ARG=--strict-config' \
  'installer invokes strict Codex validation'
assert_file_contains "$case_codex_capture" 'ARG=doctor' \
  'installer invokes Codex doctor'
assert_file_contains "$case_codex_capture" 'ARG=--json' \
  'installer requests machine-readable doctor output'
assert_file_contains "$case_codex_capture" 'ARG=--summary' \
  'installer requests the doctor summary'
assert_contains "$(/bin/cat "$case_stdout")" '/hooks' \
  'changed hook installation prints the review notice'
assert_equal 1 "$(count_backup_runs "$case_state_home")" \
  'ready install groups assets, config, and hooks in one run'
ready_backup="$(latest_backup_run "$case_state_home")"
assert_mode 700 "$ready_backup" \
  'backup run directory is private'
assert_mode 600 "$ready_backup/manifest.tsv" \
  'backup manifest is private'
assert_tree_contains "$ready_backup" 'old-notifier' \
  'ready install backs up the previous config'
assert_tree_contains "$ready_backup" '/legacy/a/codex-permission-notify' \
  'ready install backs up the previous hooks'

ready_config_hash="$(/usr/bin/shasum -a 256 "$case_codex_home/config.toml")"
ready_hooks_hash="$(/usr/bin/shasum -a 256 "$case_codex_home/hooks.json")"
ready_backup_count="$(count_backup_runs "$case_state_home")"
run_installer
ready_second_status=$?
assert_equal 0 "$ready_second_status" 'ready installer rerun succeeds'
assert_equal "$ready_config_hash" \
  "$(/usr/bin/shasum -a 256 "$case_codex_home/config.toml")" \
  'ready rerun leaves config byte-identical'
assert_equal "$ready_hooks_hash" \
  "$(/usr/bin/shasum -a 256 "$case_codex_home/hooks.json")" \
  'ready rerun leaves hooks byte-identical'
assert_equal "$ready_backup_count" "$(count_backup_runs "$case_state_home")" \
  'ready rerun creates no change backup'

run_rollback "$ready_backup"
rollback_status=$?
assert_equal 0 "$rollback_status" 'selected backup rollback succeeds'
assert_file_contains "$case_codex_home/config.toml" 'notify = ["old-notifier"]' \
  'rollback restores the previous config'
assert_file_contains "$case_codex_home/config.toml" 'notifications = true' \
  'rollback restores the previous TUI notification value'
assert_file_contains "$case_codex_home/hooks.json" \
  '/legacy/a/codex-permission-notify' \
  'rollback restores the previous hooks'
for target_name in "$target_names[@]"; do
  assert_path_absent "$case_home/.local/bin/$target_name" \
    "rollback removes newly created $target_name"
done
assert_path_absent \
  "$case_home/.local/share/codex-notify/terminal-notifier.app" \
  'rollback removes the newly created app'
assert_file_contains "$ready_backup/status" 'rolled-back' \
  'rollback marks the selected run'

# Missing Codex/Sky prerequisites leave pre-existing config and hooks untouched.
prepare_case deferred_preserve
/usr/bin/printf 'model = "keep-deferred"\n' > "$case_codex_home/config.toml"
/usr/bin/printf '{"hooks":{"PostToolUse":[]}}\n' > "$case_codex_home/hooks.json"
deferred_config_hash="$(/usr/bin/shasum -a 256 "$case_codex_home/config.toml")"
deferred_hooks_hash="$(/usr/bin/shasum -a 256 "$case_codex_home/hooks.json")"
run_installer
deferred_status=$?
assert_equal 0 "$deferred_status" 'deferred activation remains successful'
assert_equal "$deferred_config_hash" \
  "$(/usr/bin/shasum -a 256 "$case_codex_home/config.toml")" \
  'deferred activation preserves config'
assert_equal "$deferred_hooks_hash" \
  "$(/usr/bin/shasum -a 256 "$case_codex_home/hooks.json")" \
  'deferred activation preserves hooks'
assert_contains "$(/bin/cat "$case_stdout")" 'deferred' \
  'deferred activation is reported'

prepare_case ready_insert
make_sky_available
/usr/bin/printf '%s\n' \
  '# preserve while inserting owned settings' \
  'model = "insert-case"' \
  > "$case_codex_home/config.toml"
run_installer
ready_insert_status=$?
assert_equal 0 "$ready_insert_status" \
  'ready install inserts settings into a minimal config'
assert_file_contains "$case_codex_home/config.toml" \
  '# preserve while inserting owned settings' \
  'setting insertion preserves existing text'
assert_equal 1 \
  "$(/usr/bin/grep -Ec '^[[:space:]]*notify[[:space:]]*=' "$case_codex_home/config.toml")" \
  'setting insertion creates one top-level notify'
assert_file_contains "$case_codex_home/config.toml" '[tui]' \
  'setting insertion creates the TUI table'
assert_file_contains "$case_codex_home/config.toml" 'notifications = false' \
  'setting insertion disables TUI notifications'
assert_equal 1 \
  "$(/usr/bin/jq --arg command \
    "$case_home/.local/bin/codex-permission-notify" \
    '[.hooks.PermissionRequest[]?.hooks[]?
      | select(.command == $command)]
     | length' "$case_codex_home/hooks.json")" \
  'setting insertion creates the canonical hook file'

# A brand-new CODEX_HOME has no config or hooks input files. The installer
# must treat both as empty documents and create valid owned settings.
prepare_case ready_empty
make_sky_available
run_installer
ready_empty_status=$?
assert_equal 0 "$ready_empty_status" \
  'ready install succeeds without an existing config'
assert_file_contains "$case_codex_home/config.toml" 'notify = [' \
  'empty config receives a top-level notify'
assert_file_contains "$case_codex_home/config.toml" 'notifications = false' \
  'empty config receives the TUI notification setting'
assert_equal 1 \
  "$(/usr/bin/jq \
    '[.hooks.PermissionRequest[]?.hooks[]?
      | select(.command | endswith("/codex-permission-notify"))]
     | length' "$case_codex_home/hooks.json")" \
  'empty hooks receive one canonical permission handler'
assert_mode 600 "$case_codex_home/config.toml" \
  'new config is private'
assert_mode 600 "$case_codex_home/hooks.json" \
  'new hooks are private'

# Rollback must never erase settings added after installation. A changed
# managed target makes the selected run stale, so rollback refuses the whole
# operation and leaves every installed target active.
ready_empty_backup="$(latest_backup_run "$case_state_home")"
/usr/bin/printf '%s\n' \
  '' \
  '[mcp_servers.after_install]' \
  'command = "/tmp/keep-after-install"' \
  >> "$case_codex_home/config.toml"
"/usr/bin/jq" \
  '.metadata.after_install = "keep-me"' \
  "$case_codex_home/hooks.json" \
  > "$case_codex_home/hooks.json.after-install"
/bin/mv \
  "$case_codex_home/hooks.json.after-install" \
  "$case_codex_home/hooks.json"

run_rollback "$ready_empty_backup"
ready_empty_rollback_status=$?
if (( ready_empty_rollback_status == 0 )); then
  print -u2 'FAIL: rollback with post-install drift returns success'
  (( failures += 1 ))
fi
assert_contains "$(/bin/cat "$case_stderr")" 'changed after install' \
  'rollback explains stale managed state'
assert_file_contains "$case_codex_home/config.toml" \
  '/tmp/keep-after-install' \
  'refused rollback preserves post-install config changes'
assert_file_contains "$case_codex_home/hooks.json" \
  '"after_install": "keep-me"' \
  'refused rollback preserves post-install hook changes'
for target_name in "$target_names[@]"; do
  assert_link_target \
    "$case_home/.local/bin/$target_name" \
    "$module_dir/bin/$target_name" \
    "refused rollback preserves installed $target_name"
done
assert_file_contains "$ready_empty_backup/status" 'complete' \
  'refused rollback leaves the selected run complete'

# The intentionally narrow TOML merger must not interpret key- or table-like
# text inside an unrelated multiline string. Unsupported multiline syntax
# aborts before any target changes and preserves the source bytes.
prepare_case multiline_string
make_sky_available
/usr/bin/printf '%s\n' \
  'model = "keep-multiline"' \
  'description = """' \
  'notify = ["this is text, not a key"]' \
  '[tui]' \
  'notifications = true' \
  '"""' \
  > "$case_codex_home/config.toml"
/usr/bin/printf '{"hooks":{}}\n' > "$case_codex_home/hooks.json"
multiline_config_hash="$(/usr/bin/shasum -a 256 "$case_codex_home/config.toml")"
run_installer
multiline_status=$?
if (( multiline_status == 0 )); then
  print -u2 'FAIL: unsupported multiline TOML returns success'
  (( failures += 1 ))
fi
assert_equal "$multiline_config_hash" \
  "$(/usr/bin/shasum -a 256 "$case_codex_home/config.toml")" \
  'unsupported multiline TOML remains byte-identical'
assert_path_absent "$case_home/.local/bin/codex-notify" \
  'unsupported multiline TOML leaves runtime targets untouched'

# Unsupported multiline notify and failed config.load validation abort before
# any active target is replaced.
prepare_case ambiguous_notify
make_sky_available
/usr/bin/printf '%s\n' \
  'model = "keep-ambiguous"' \
  'notify = [' \
  '  "old",' \
  ']' \
  > "$case_codex_home/config.toml"
/usr/bin/printf '{"hooks":{}}\n' > "$case_codex_home/hooks.json"
/bin/mkdir -p "$case_home/.local/bin"
/usr/bin/printf 'keep-before-ambiguous\n' \
  > "$case_home/.local/bin/codex-notify"
/bin/chmod 755 "$case_home/.local/bin/codex-notify"
ambiguous_config_hash="$(/usr/bin/shasum -a 256 "$case_codex_home/config.toml")"
run_installer
ambiguous_status=$?
if (( ambiguous_status == 0 )); then
  print -u2 'FAIL: ambiguous multiline notify returns success'
  (( failures += 1 ))
fi
assert_equal "$ambiguous_config_hash" \
  "$(/usr/bin/shasum -a 256 "$case_codex_home/config.toml")" \
  'ambiguous notify leaves config unchanged'
assert_regular_file "$case_home/.local/bin/codex-notify" \
  'ambiguous notify leaves runtime script unchanged'
assert_file_contains "$case_home/.local/bin/codex-notify" \
  'keep-before-ambiguous' \
  'ambiguous notify preserves runtime script content'

prepare_case doctor_unrelated_failure
make_sky_available
/usr/bin/printf 'model = "doctor-unrelated-failure"\n' \
  > "$case_codex_home/config.toml"
run_installer \
  CODEX_TEST_CODEX_STATUS=ok \
  CODEX_TEST_CODEX_EXIT=1
doctor_unrelated_status=$?
assert_equal 0 "$doctor_unrelated_status" \
  'unrelated doctor failures do not reject config.load ok'
assert_file_contains "$case_codex_home/config.toml" 'notify = [' \
  'config.load ok candidate activates despite doctor overall failure'

prepare_case doctor_failure
make_sky_available
/usr/bin/printf '%s\n' \
  'model = "keep-doctor-failure"' \
  'notify = ["old-doctor"]' \
  > "$case_codex_home/config.toml"
/usr/bin/printf '{"hooks":{}}\n' > "$case_codex_home/hooks.json"
/bin/mkdir -p "$case_home/.local/bin"
/usr/bin/printf 'keep-before-doctor\n' \
  > "$case_home/.local/bin/codex-notify"
/bin/chmod 755 "$case_home/.local/bin/codex-notify"
doctor_config_hash="$(/usr/bin/shasum -a 256 "$case_codex_home/config.toml")"
run_installer CODEX_TEST_CODEX_STATUS=error
doctor_failure_status=$?
if (( doctor_failure_status == 0 )); then
  print -u2 'FAIL: config.load error returns success'
  (( failures += 1 ))
fi
assert_equal "$doctor_config_hash" \
  "$(/usr/bin/shasum -a 256 "$case_codex_home/config.toml")" \
  'doctor failure leaves config unchanged'
assert_regular_file "$case_home/.local/bin/codex-notify" \
  'doctor failure leaves runtime script unchanged'
assert_file_contains "$case_home/.local/bin/codex-notify" \
  'keep-before-doctor' \
  'doctor failure preserves runtime script content'

if (( failures > 0 )); then
  print -u2 "FAIL: $failures installer assertion(s) failed"
  exit 1
fi

print 'PASS: notification installer behavior'

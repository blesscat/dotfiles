#!/bin/zsh

set -u
unsetopt BG_NICE
setopt PIPE_FAIL
umask 077

readonly module_dir="${0:A:h}"
readonly source_bin_dir="$module_dir/bin"
readonly home_dir="${HOME:-}"
readonly codex_home="${CODEX_HOME:-${home_dir:+$home_dir/.codex}}"
readonly state_home="${XDG_STATE_HOME:-${home_dir:+$home_dir/.local/state}}"
readonly install_bin_dir="$home_dir/.local/bin"
readonly app_parent="$home_dir/.local/share/codex-notify"
readonly app_target="$app_parent/terminal-notifier.app"
readonly config_target="$codex_home/config.toml"
readonly hooks_target="$codex_home/hooks.json"
readonly backup_root="$state_home/cider/backups/codex-notify"
readonly brew_bin="${CODEX_NOTIFY_BREW:-${commands[brew]-}}"
readonly codesign_bin="${CODEX_NOTIFY_CODESIGN:-${commands[codesign]-}}"
readonly jq_bin="${CODEX_NOTIFY_JQ:-${commands[jq]-}}"
readonly codex_bin="${CODEX_NOTIFY_CODEX:-${commands[codex]-}}"
readonly sky_client="${CODEX_NOTIFY_SKY_CLIENT:-$codex_home/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient}"
readonly -a runtime_names=(
  codex-notify
  codex-permission-notify
  codex-notification-route
)

stage_app=''
stage_config=''
stage_hooks=''
validation_home=''
run_dir=''
hook_changed=0
typeset -a changed_kinds changed_targets changed_sources
typeset -a backup_states backup_relatives rollback_stages

cleanup() {
  local cleanup_path

  for cleanup_path in \
    "$stage_app" \
    "$stage_config" \
    "$stage_hooks" \
    "$validation_home" \
    "$rollback_stages[@]"; do
    if [[ -n "$cleanup_path" \
        && ( -e "$cleanup_path" || -L "$cleanup_path" ) ]]; then
      /bin/rm -rf -- "$cleanup_path"
    fi
  done
}

trap cleanup EXIT HUP INT TERM

fail() {
  print -u2 -- "codex-notify install: $*"
  exit 1
}

target_exists() {
  [[ -e "$1" || -L "$1" ]]
}

remove_target() {
  local target="$1"

  if [[ -e "$target" || -L "$target" ]]; then
    /bin/rm -rf -- "$target"
  fi
}

copy_preserving() {
  local source="$1"
  local destination="$2"

  /bin/mkdir -p "${destination:h}" || return 1
  /bin/cp -pPR "$source" "$destination"
}

target_fingerprint() {
  local target="$1"
  local kind
  local mode
  local digest
  local linked

  if [[ -L "$target" ]]; then
    kind='link'
    linked="$(/usr/bin/readlink "$target")" || return 1
    digest="$(/usr/bin/printf '%s' "$linked" \
      | /usr/bin/shasum -a 256)" || return 1
  elif [[ -f "$target" ]]; then
    kind='file'
    mode="$(/usr/bin/stat -f '%Lp' "$target")" || return 1
    digest="$(/usr/bin/shasum -a 256 "$target")" || return 1
  elif [[ -d "$target" ]]; then
    kind='directory'
    mode="$(/usr/bin/stat -f '%Lp' "$target")" || return 1
    digest="$(/usr/bin/tar -cf - -C "${target:h}" "${target:t}" \
      | /usr/bin/shasum -a 256)" || return 1
  elif [[ ! -e "$target" ]]; then
    print -- 'absent'
    return 0
  else
    return 1
  fi

  digest="${digest%%[[:space:]]*}"
  [[ ${#digest} == 64 && "$digest" != *[^0-9a-f]* ]] || return 1
  if [[ "$kind" == 'link' ]]; then
    print -- "$kind:$digest"
  else
    print -- "$kind:$mode:$digest"
  fi
}

record_post_install_state() {
  local index
  local target
  local fingerprint
  local post_install="$run_dir/post-install.tsv"

  : > "$post_install" || return 1
  for (( index = 1; index <= $#changed_targets; index += 1 )); do
    target="$changed_targets[index]"
    fingerprint="$(target_fingerprint "$target")" || return 1
    /usr/bin/printf '%s\t%s\n' \
      "$target" \
      "$fingerprint" >> "$post_install" || return 1
  done
}

is_current_link() {
  local target="$1"
  local source="$2"
  local linked=''

  [[ -L "$target" ]] || return 1
  linked="$(/usr/bin/readlink "$target" 2>/dev/null)" || return 1
  [[ "$linked" == "$source" ]]
}

is_managed_target() {
  local target="$1"

  case "$target" in
    "$install_bin_dir/codex-notify" | \
    "$install_bin_dir/codex-permission-notify" | \
    "$install_bin_dir/codex-notification-route" | \
    "$app_target" | \
    "$config_target" | \
    "$hooks_target")
      return 0
      ;;
  esac

  return 1
}

backup_contract_for_target() {
  local target="$1"

  case "$target" in
    "$install_bin_dir/codex-notify")
      print -- $'link\ttargets/local-bin/codex-notify'
      ;;
    "$install_bin_dir/codex-permission-notify")
      print -- $'link\ttargets/local-bin/codex-permission-notify'
      ;;
    "$install_bin_dir/codex-notification-route")
      print -- $'link\ttargets/local-bin/codex-notification-route'
      ;;
    "$app_target")
      print -- $'app\ttargets/local-share/codex-notify/terminal-notifier.app'
      ;;
    "$config_target")
      print -- $'file\ttargets/codex/config.toml'
      ;;
    "$hooks_target")
      print -- $'file\ttargets/codex/hooks.json'
      ;;
    *)
      return 1
      ;;
  esac
}

backup_changed_target() {
  local index="$1"
  local target="$changed_targets[index]"
  local relative="$backup_relatives[index]"
  local state='absent'

  if target_exists "$target"; then
    state='present'
    copy_preserving "$target" "$run_dir/$relative" || return 1
  fi

  backup_states[index]="$state"
  /usr/bin/printf '%s\t%s\t%s\t%s\n' \
    "$changed_kinds[index]" \
    "$target" \
    "$state" \
    "$relative" >> "$run_dir/manifest.tsv"
}

restore_current_run() {
  local index
  local target
  local state
  local relative

  for (( index = $#changed_targets; index >= 1; index -= 1 )); do
    target="$changed_targets[index]"
    state="${backup_states[index]-absent}"
    relative="$backup_relatives[index]"
    remove_target "$target"
    if [[ "$state" == 'present' ]]; then
      copy_preserving "$run_dir/$relative" "$target" || \
        print -u2 -- "codex-notify install: rollback could not restore $target"
    fi
  done

  if [[ -n "$run_dir" && -d "$run_dir" ]]; then
    /usr/bin/printf 'rolled-back\n' > "$run_dir/status"
  fi
}

activate_link() {
  local source="$1"
  local target="$2"
  local staged_link="$target.stage-$$"

  remove_target "$staged_link"
  /bin/ln -s "$source" "$staged_link" || return 1
  if [[ -d "$target" && ! -L "$target" ]]; then
    remove_target "$target"
  fi
  /bin/mv -f "$staged_link" "$target"
}

activate_file() {
  local source="$1"
  local target="$2"

  if [[ -d "$target" && ! -L "$target" ]]; then
    return 1
  fi
  /bin/mv -f "$source" "$target"
}

merge_config_candidate() {
  local input='/dev/null'
  local previous_notify
  local notify_value
  local notify_line

  if [[ -f "$config_target" ]]; then
    input="$config_target"
  fi

  # This merger is deliberately line-oriented. Refuse TOML multiline strings
  # before emitting a candidate so key-like text inside them cannot be
  # mistaken for active configuration.
  /usr/bin/awk '
    index($0, "\"\"\"") > 0 \
      || index($0, sprintf("%c%c%c", 39, 39, 39)) > 0 { exit 42 }
  ' "$input" || return 1

  previous_notify="$("$jq_bin" -cn \
    --arg wrapper "$install_bin_dir/codex-notify" \
    '[$wrapper, "--native-only"]')" || return 1
  notify_value="$("$jq_bin" -cn \
    --arg sky "$sky_client" \
    --arg previous "$previous_notify" \
    '[$sky, "turn-ended", "--previous-notify", $previous]')" || return 1
  notify_line="notify = $notify_value"

  CODEX_NOTIFY_CONFIG_NOTIFY_LINE="$notify_line" /usr/bin/awk \
    -v tui_line='notifications = false' '
      BEGIN {
        notify_line = ENVIRON["CODEX_NOTIFY_CONFIG_NOTIFY_LINE"]
        section = "top"
        notify_seen = 0
        tui_seen = 0
        tui_notification_seen = 0
        bad = 0
      }

      function finish_section() {
        if (section == "top" && notify_seen == 0) {
          print notify_line
          notify_seen = 1
        } else if (section == "tui" && tui_notification_seen == 0) {
          print tui_line
          tui_notification_seen = 1
        }
      }

      {
        line = $0

        if (line ~ /^[ \t]*\[/) {
          finish_section()
          if (line ~ /^[ \t]*\[tui\][ \t]*(#.*)?$/) {
            section = "tui"
            tui_seen += 1
            tui_notification_seen = 0
            if (tui_seen > 1) {
              bad = 1
            }
          } else {
            section = "other"
          }
          print line
          next
        }

        if (section == "top" \
            && line ~ /^[ \t]*notify[ \t]*=/) {
          notify_seen += 1
          if (notify_seen > 1) {
            bad = 1
            next
          }

          rhs = line
          sub(/^[^=]*=[ \t]*/, "", rhs)
          if (rhs == "" \
              || index(rhs, "\"\"\"") > 0 \
              || index(rhs, sprintf("%c%c%c", 39, 39, 39)) > 0 \
              || (rhs ~ /^\[/ && rhs !~ /\][ \t]*(#.*)?$/)) {
            bad = 1
          }
          print notify_line
          next
        }

        if (section == "tui" \
            && line ~ /^[ \t]*notifications[ \t]*=/) {
          if (tui_notification_seen == 0) {
            print tui_line
            tui_notification_seen = 1
          }
          next
        }

        print line
      }

      END {
        finish_section()
        if (tui_seen == 0) {
          if (NR > 0) {
            print ""
          }
          print "[tui]"
          print tui_line
        }
        if (bad) {
          exit 42
        }
      }
    ' "$input" > "$stage_config"
}

merge_hooks_candidate() {
  local hooks_input="$validation_home/hooks-input.json"

  if [[ -f "$hooks_target" ]]; then
    /bin/cp -p "$hooks_target" "$hooks_input" || return 1
  else
    /usr/bin/printf '{}\n' > "$hooks_input" || return 1
  fi

  "$jq_bin" \
    --arg command "$install_bin_dir/codex-permission-notify" '
      def owned:
        type == "object"
        and .type == "command"
        and (.command | type == "string")
        and (.command | test("(^|/)codex-permission-notify$"));

      def cleaned_group:
        if type != "object" then
          error("PermissionRequest groups must be objects")
        else
          (.hooks // []) as $original
          | if ($original | type) != "array" then
              error("PermissionRequest hooks must be arrays")
            else
              ($original | map(select((owned) | not))) as $remaining
              | if (($original | length) > 0
                    and ($remaining | length) == 0) then
                  empty
                else
                  . + {hooks: $remaining}
                end
            end
        end;

      if type != "object" then
        error("hooks.json must contain an object")
      elif (has("hooks") and .hooks != null
            and (.hooks | type) != "object") then
        error("hooks must be an object")
      else
        .hooks = (.hooks // {})
        | (.hooks.PermissionRequest // []) as $groups
        | if ($groups | type) != "array" then
            error("PermissionRequest must be an array")
          else
            .hooks.PermissionRequest = (
              [$groups[] | cleaned_group]
              + [{
                  matcher: "*",
                  hooks: [{
                    type: "command",
                    command: $command,
                    timeout: 10
                  }]
                }]
            )
          end
      end
    ' "$hooks_input" > "$stage_hooks"
}

validate_config_candidate() {
  local doctor_output="$validation_home/doctor.json"

  /bin/cp -p "$stage_config" "$validation_home/config.toml" || return 1
  /usr/bin/env CODEX_HOME="$validation_home" \
    "$codex_bin" --strict-config doctor --json --summary \
    > "$doctor_output" 2> "$validation_home/doctor.stderr"
  "$jq_bin" -e \
    '.checks["config.load"].status == "ok"' \
    "$doctor_output" >/dev/null 2>&1
}

rollback_selected_run() {
  local selector="$1"
  local selected
  local normalized_root
  local manifest
  local kind
  local target
  local state
  local relative
  local index
  local staged
  local expected_target
  local expected_fingerprint
  local actual_fingerprint
  local expected_contract
  local expected_kind
  local expected_relative
  local backup_path
  local backup_parent
  local resolved_parent
  local line_number=0
  local post_install
  local run_status
  typeset -a rollback_targets rollback_states rollback_relatives
  typeset -a rollback_post_targets rollback_post_fingerprints
  typeset -A rollback_seen_targets

  if [[ "$selector" == /* ]]; then
    selected="$selector"
  else
    selected="$backup_root/$selector"
  fi

  selected="${selected:A}"
  normalized_root="${backup_root:A}"
  [[ "$selected" == "$normalized_root"/* ]] || \
    fail 'rollback run must be inside the codex-notify backup root'
  manifest="$selected/manifest.tsv"
  [[ -f "$manifest" && ! -L "$manifest" ]] || \
    fail "rollback manifest is missing or unsafe: $manifest"
  post_install="$selected/post-install.tsv"
  [[ -f "$post_install" && ! -L "$post_install" ]] || \
    fail "rollback post-install state is missing or unsafe: $post_install"
  [[ -f "$selected/status" && ! -L "$selected/status" ]] || \
    fail "rollback status is missing or unsafe: $selected/status"
  run_status="$(/bin/cat "$selected/status" 2>/dev/null)" || \
    fail "rollback status is missing: $selected/status"
  [[ "$run_status" == 'complete' ]] || \
    fail "rollback run is not complete: $selected"

  rollback_targets=()
  rollback_states=()
  rollback_relatives=()
  rollback_seen_targets=()
  while IFS=$'\t' read -r kind target state relative; do
    (( line_number += 1 ))
    if (( line_number == 1 )); then
      [[ "$kind" == 'version' && "$target" == '2' \
          && -z "$state" && -z "$relative" ]] || \
        fail 'rollback manifest must start with exactly one version 2 header'
      continue
    fi
    [[ "$state" == 'present' || "$state" == 'absent' ]] || \
      fail 'rollback manifest contains an invalid state'
    expected_contract="$(backup_contract_for_target "$target")" || \
      fail "rollback manifest contains an unmanaged target: $target"
    expected_kind="${expected_contract%%$'\t'*}"
    expected_relative="${expected_contract#*$'\t'}"
    [[ "$kind" == "$expected_kind" ]] || \
      fail "rollback manifest contains an invalid kind for $target"
    [[ "$relative" == "$expected_relative" ]] || \
      fail "rollback manifest does not use the canonical backup path for $target"
    [[ -z "${rollback_seen_targets[$target]-}" ]] || \
      fail "rollback manifest repeats a managed target: $target"
    rollback_seen_targets[$target]=1
    if [[ "$state" == 'present' && ! -e "$selected/$relative" \
        && ! -L "$selected/$relative" ]]; then
      fail "rollback backup is missing: $selected/$relative"
    fi
    if [[ "$state" == 'present' ]]; then
      backup_path="$selected/$relative"
      backup_parent="${backup_path:h}"
      [[ -d "$backup_parent" ]] || \
        fail "rollback backup parent is missing: $backup_parent"
      resolved_parent="${backup_parent:A}"
      [[ "$resolved_parent" == "$selected" \
          || "$resolved_parent" == "$selected"/* ]] || \
        fail "rollback backup path escapes the selected run: $backup_path"
    fi
    rollback_targets+=("$target")
    rollback_states+=("$state")
    rollback_relatives+=("$relative")
  done < "$manifest"

  (( line_number > 0 )) || fail 'rollback manifest is empty'
  (( $#rollback_targets > 0 )) || fail 'rollback manifest has no targets'

  rollback_post_targets=()
  rollback_post_fingerprints=()
  while IFS=$'\t' read -r expected_target expected_fingerprint; do
    is_managed_target "$expected_target" || \
      fail "post-install state contains an unmanaged target: $expected_target"
    [[ -n "$expected_fingerprint" ]] || \
      fail 'post-install state contains an empty fingerprint'
    rollback_post_targets+=("$expected_target")
    rollback_post_fingerprints+=("$expected_fingerprint")
  done < "$post_install"

  (( $#rollback_post_targets == $#rollback_targets )) || \
    fail 'post-install state does not match the rollback manifest'
  for (( index = 1; index <= $#rollback_targets; index += 1 )); do
    [[ "$rollback_post_targets[index]" == "$rollback_targets[index]" ]] || \
      fail 'post-install state target order does not match the rollback manifest'
    target="$rollback_targets[index]"
    actual_fingerprint="$(target_fingerprint "$target")" || \
      fail "could not inspect managed target before rollback: $target"
    [[ "$actual_fingerprint" == "$rollback_post_fingerprints[index]" ]] || \
      fail "rollback refused because managed target changed after install: $target"
  done

  rollback_stages=()
  for (( index = 1; index <= $#rollback_targets; index += 1 )); do
    if [[ "$rollback_states[index]" == 'present' ]]; then
      staged="$rollback_targets[index].rollback-stage-$$"
      remove_target "$staged"
      copy_preserving \
        "$selected/$rollback_relatives[index]" \
        "$staged" || fail "could not stage rollback for $rollback_targets[index]"
      rollback_stages[index]="$staged"
    else
      rollback_stages[index]=''
    fi
  done

  for (( index = $#rollback_targets; index >= 1; index -= 1 )); do
    target="$rollback_targets[index]"
    remove_target "$target"
    if [[ "$rollback_states[index]" == 'present' ]]; then
      /bin/mv "$rollback_stages[index]" "$target" || \
        fail "could not restore $target"
      rollback_stages[index]=''
    fi
  done

  /usr/bin/printf 'rolled-back\n' > "$selected/status"
  print -- "Rolled back notification installation from $selected."
  exit 0
}

[[ -n "$home_dir" && "$home_dir" == /* ]] || \
  fail 'HOME must be an absolute path'
[[ -n "$codex_home" && "$codex_home" == /* ]] || \
  fail 'CODEX_HOME must be an absolute path'
[[ -n "$state_home" && "$state_home" == /* ]] || \
  fail 'XDG_STATE_HOME must resolve to an absolute path'

if (( $# == 2 )) && [[ "$1" == '--rollback' ]]; then
  rollback_selected_run "$2"
elif (( $# != 0 )); then
  fail 'usage: install.zsh [--rollback <backup-run>]'
fi

for runtime_name in "$runtime_names[@]"; do
  [[ -x "$source_bin_dir/$runtime_name" ]] || \
    fail "module runtime is missing or not executable: $source_bin_dir/$runtime_name"
done

[[ -n "$brew_bin" && -x "$brew_bin" ]] || \
  fail 'Homebrew is required but was not found'
[[ -n "$codesign_bin" && -x "$codesign_bin" ]] || \
  fail 'codesign is required but was not found'
[[ -n "$jq_bin" && -x "$jq_bin" ]] || \
  fail 'jq is required but was not found'

formula_prefix="$("$brew_bin" --prefix terminal-notifier 2>/dev/null)" || \
  fail 'could not resolve the terminal-notifier Homebrew prefix'
[[ -n "$formula_prefix" && "$formula_prefix" == /* ]] || \
  fail 'Homebrew returned an invalid terminal-notifier prefix'

source_app="$formula_prefix/terminal-notifier.app"
source_notifier="$source_app/Contents/MacOS/terminal-notifier"
[[ -d "$source_app" && -x "$source_notifier" ]] || \
  fail "Homebrew terminal-notifier app is unavailable: $source_app"

/bin/mkdir -p "$install_bin_dir" "$app_parent" || \
  fail 'could not create runtime target directories'

stage_app="$app_parent/.terminal-notifier.app.stage-$$"
remove_target "$stage_app"
/bin/cp -pPR "$source_app" "$stage_app" || \
  fail 'could not stage the terminal-notifier app'

"$codesign_bin" --force --deep --sign - "$stage_app" >/dev/null 2>&1 || \
  fail 'could not ad-hoc sign the staged terminal-notifier app'
"$codesign_bin" --verify --deep --strict "$stage_app" >/dev/null 2>&1 || \
  fail 'staged terminal-notifier app failed strict signature verification'

activation_ready=0
if [[ -n "$codex_bin" && -x "$codex_bin" && -x "$sky_client" ]]; then
  activation_ready=1
fi

if (( activation_ready )); then
  [[ ! -d "$config_target" && ! -d "$hooks_target" ]] || \
    fail 'Codex config and hooks targets must not be directories'
  /bin/mkdir -p "$codex_home" || fail 'could not create CODEX_HOME'
  stage_config="$codex_home/.config.toml.codex-notify-stage-$$"
  stage_hooks="$codex_home/.hooks.json.codex-notify-stage-$$"
  remove_target "$stage_config"
  remove_target "$stage_hooks"
  validation_home="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-notify-validate.XXXXXX")" || \
    fail 'could not create a config validation directory'

  merge_config_candidate || \
    fail 'config.toml has unsupported multiline strings or ambiguous owned settings; edit it manually and rerun'
  merge_hooks_candidate || \
    fail 'hooks.json could not be merged safely'
  validate_config_candidate || \
    fail 'staged config failed Codex config.load validation'
fi

changed_kinds=()
changed_targets=()
changed_sources=()
backup_relatives=()
backup_states=()

for runtime_name in "$runtime_names[@]"; do
  source_path="$source_bin_dir/$runtime_name"
  target_path="$install_bin_dir/$runtime_name"
  if ! is_current_link "$target_path" "$source_path"; then
    changed_kinds+=('link')
    changed_targets+=("$target_path")
    changed_sources+=("$source_path")
    backup_relatives+=("targets/local-bin/$runtime_name")
  fi
done

app_changed=1
if [[ -d "$app_target" && ! -L "$app_target" ]] \
    && "$codesign_bin" --verify --deep --strict \
      "$app_target" >/dev/null 2>&1 \
    && /usr/bin/diff -qr "$app_target" "$stage_app" >/dev/null 2>&1; then
  app_changed=0
fi
if (( app_changed )); then
  changed_kinds+=('app')
  changed_targets+=("$app_target")
  changed_sources+=("$stage_app")
  backup_relatives+=('targets/local-share/codex-notify/terminal-notifier.app')
else
  remove_target "$stage_app"
  stage_app=''
fi

if (( activation_ready )); then
  if [[ ! -f "$config_target" ]] \
      || ! /usr/bin/cmp -s "$config_target" "$stage_config"; then
    changed_kinds+=('file')
    changed_targets+=("$config_target")
    changed_sources+=("$stage_config")
    backup_relatives+=('targets/codex/config.toml')
  else
    remove_target "$stage_config"
    stage_config=''
  fi

  if [[ ! -f "$hooks_target" ]] \
      || ! /usr/bin/cmp -s "$hooks_target" "$stage_hooks"; then
    changed_kinds+=('file')
    changed_targets+=("$hooks_target")
    changed_sources+=("$stage_hooks")
    backup_relatives+=('targets/codex/hooks.json')
    hook_changed=1
  else
    remove_target "$stage_hooks"
    stage_hooks=''
  fi
fi

if (( $#changed_targets > 0 )); then
  run_id="$(/bin/date '+%Y%m%dT%H%M%S')-$$"
  run_dir="$backup_root/$run_id"
  /bin/mkdir -p "$run_dir" || fail 'could not create the installer backup run'
  /usr/bin/printf 'version\t2\n' > "$run_dir/manifest.tsv"
  /usr/bin/printf 'preparing\n' > "$run_dir/status"

  for (( index = 1; index <= $#changed_targets; index += 1 )); do
    if ! backup_changed_target "$index"; then
      /bin/rm -rf -- "$run_dir"
      fail "could not back up $changed_targets[index]"
    fi
  done

  for (( index = 1; index <= $#changed_targets; index += 1 )); do
    case "$changed_kinds[index]" in
      link)
        if ! activate_link \
          "$changed_sources[index]" \
          "$changed_targets[index]"; then
          restore_current_run
          fail "could not activate $changed_targets[index]"
        fi
        ;;
      app)
        remove_target "$changed_targets[index]"
        if ! /bin/mv "$changed_sources[index]" "$changed_targets[index]"; then
          restore_current_run
          fail 'could not activate the terminal-notifier app'
        fi
        stage_app=''
        ;;
      file)
        if ! activate_file \
          "$changed_sources[index]" \
          "$changed_targets[index]"; then
          restore_current_run
          fail "could not activate $changed_targets[index]"
        fi
        if [[ "$changed_sources[index]" == "$stage_config" ]]; then
          stage_config=''
        elif [[ "$changed_sources[index]" == "$stage_hooks" ]]; then
          stage_hooks=''
        fi
        ;;
    esac
  done

  if ! record_post_install_state; then
    restore_current_run
    fail 'could not record post-install state for safe rollback'
  fi

  /usr/bin/printf 'complete\n' > "$run_dir/status"
  print -- "Installed notification assets and owned settings (backup run: $run_dir)."
else
  print -- 'Notification assets and owned settings are already current.'
fi

if (( activation_ready )); then
  print -- 'Codex notification config and permission hook are active.'
  if (( hook_changed )); then
    print -- 'Review and trust the changed permission hook through /hooks.'
  fi
else
  print -- 'Codex notification activation deferred: Codex CLI or Sky Computer Use is unavailable.'
  print -- "Rerun when ready: $module_dir/install.zsh"
fi

exit 0

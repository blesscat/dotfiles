#!/bin/bash

set -euo pipefail

readonly test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly repo_dir="$(cd -- "$test_dir/.." && pwd -P)"
readonly real_limactl="${LIMA_TEST_LIMACTL:-$(command -v limactl 2>/dev/null || true)}"
readonly tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

/usr/bin/ruby "$test_dir/lima-config-contract-test.rb"
/bin/bash "$test_dir/lima-guest-layout-test.sh"
/bin/bash "$test_dir/lima-codex-update-test.sh"
/bin/bash "$test_dir/lima-guest-native-migrate-test.sh"

failures=0

fail_assertion() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    fail_assertion "$label (missing '$needle')"
  fi
}

assert_log_line() {
  local log_file="$1"
  local expected="$2"
  local label="$3"

  if ! grep -Fqx "$expected" "$log_file"; then
    fail_assertion "$label (missing '$expected')"
  fi
}

assert_log_line_absent() {
  local log_file="$1"
  local unexpected="$2"
  local label="$3"

  if grep -Fqx "$unexpected" "$log_file"; then
    fail_assertion "$label (found '$unexpected')"
  fi
}

assert_log_empty() {
  local log_file="$1"
  local label="$2"

  if [[ -s "$log_file" ]]; then
    fail_assertion "$label (unexpected command calls: $(tr '\n' ';' < "$log_file"))"
  fi
}

assert_event_order() {
  local event_log="$1"
  local first_event="$2"
  local second_event="$3"
  local label="$4"
  local first_line
  local second_line

  first_line="$(awk -v needle="$first_event" '$0 == needle { print NR; exit }' "$event_log")"
  second_line="$(awk -v needle="$second_event" '$0 == needle { print NR; exit }' "$event_log")"
  if [[ -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
    fail_assertion "$label (expected '$first_event' before '$second_event')"
  fi
}

run_success() {
  local output_file="$1"
  shift

  if ! "$@" >"$output_file" 2>&1; then
    fail_assertion "command failed: $*\n$(tr '\n' ';' < "$output_file")"
    return 1
  fi
}

prepare_case() {
  local case_name="$1"
  case_dir="$tmp_dir/$case_name"
  mkdir -p "$case_dir"

  export FAKE_EVENT_LOG="$case_dir/events.log"
  export FAKE_LIMA_LOG="$case_dir/limactl.log"
  export FAKE_LIMA_STATE="$case_dir/lima.state"
  export FAKE_DOCKER_LOG="$case_dir/docker.log"
  export FAKE_DOCKER_CONTEXTS="$case_dir/docker.contexts"
  export FAKE_DOCKER_ACTIVE="$case_dir/docker.active"
  export FAKE_BREW_LOG="$case_dir/brew.log"
  export FAKE_UNAME_SYSTEM=Darwin

  : > "$FAKE_EVENT_LOG"
  : > "$FAKE_LIMA_LOG"
  : > "$FAKE_LIMA_STATE"
  : > "$FAKE_DOCKER_LOG"
  : > "$FAKE_DOCKER_CONTEXTS"
  : > "$FAKE_DOCKER_ACTIVE"
  : > "$FAKE_BREW_LOG"
}

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"

printf '%s\n' \
  '#!/bin/bash' \
  'set -euo pipefail' \
  'event_log="${FAKE_EVENT_LOG:?}"' \
  'log="${FAKE_LIMA_LOG:?}"' \
  'state="${FAKE_LIMA_STATE:?}"' \
  'printf "limactl %s\\n" "$*" >> "$log"' \
  'printf "limactl %s\\n" "$*" >> "$event_log"' \
  'case "${1:-}" in' \
  '  list)' \
  '    if [[ "${2:-}" == "--format" && "${3:-}" == "{{.Name}}" ]]; then' \
  '      if [[ -s "$state" ]]; then /bin/cat "$state"; fi' \
  '    elif [[ "${3:-}" == --format=unix://* ]]; then' \
  '      instance="${2:?}"' \
  '      if [[ ! -s "$state" ]] || ! /usr/bin/grep -Fxq "$instance" "$state"; then' \
  '        printf "Lima instance does not exist: %s\\n" "$instance" >&2' \
  '        exit 1' \
  '      fi' \
  '      printf "unix:///tmp/fake-lima/%s/sock/docker.sock\\n" "$instance"' \
  '    elif [[ -n "${2:-}" && "$#" -eq 2 ]]; then' \
  '      if [[ -s "$state" ]] && /usr/bin/grep -Fxq "$2" "$state"; then printf "%s\\n" "$2"; fi' \
  '    else' \
  '      printf "Unexpected fake limactl list arguments: %s\\n" "$*" >&2' \
  '      exit 2' \
  '    fi' \
  '    ;;' \
  '  start)' \
  '    if [[ "${2:-}" == --name=* ]]; then' \
  '      instance="${2#--name=}"' \
  '    else' \
  '      instance="${2:-dev}"' \
  '    fi' \
  '    if [[ ! -s "$state" ]] || ! /usr/bin/grep -Fxq "$instance" "$state"; then' \
  '      printf "%s\\n" "$instance" >> "$state"' \
  '    fi' \
  '    ;;' \
  '  stop)' \
  '    [[ -n "${2:-}" ]]' \
  '    ;;' \
  '  autostart)' \
  '    [[ "${2:-}" == enable && "${3:-}" == "--condition=login" && -n "${4:-}" ]]' \
  '    ;;' \
  '  delete)' \
  '    instance="${2:?}"' \
  '    /usr/bin/grep -Fvx "$instance" "$state" > "$state.tmp" || true' \
  '    /bin/mv "$state.tmp" "$state"' \
  '    ;;' \
  '  *)' \
  '    printf "Unexpected fake limactl command: %s\\n" "$*" >&2' \
  '    exit 2' \
  '    ;;' \
  'esac' > "$fake_bin/limactl"

printf '%s\n' \
  '#!/bin/bash' \
  'set -euo pipefail' \
  'event_log="${FAKE_EVENT_LOG:?}"' \
  'log="${FAKE_DOCKER_LOG:?}"' \
  'contexts="${FAKE_DOCKER_CONTEXTS:?}"' \
  'active="${FAKE_DOCKER_ACTIVE:?}"' \
  'printf "docker %s\\n" "$*" >> "$log"' \
  'printf "docker %s\\n" "$*" >> "$event_log"' \
  'case "${1:-}" in' \
  '  context)' \
  '    case "${2:-}" in' \
  '      inspect)' \
  '        context="${3:?}"' \
  '        if [[ -s "$contexts" ]] && /usr/bin/grep -Fxq "$context" "$contexts"; then exit 0; fi' \
  '        exit 1' \
  '        ;;' \
  '      create|update)' \
  '        context="${3:?}"' \
  '        [[ "${4:-}" == "--docker" && -n "${5:-}" ]]' \
  '        if [[ ! -s "$contexts" ]] || ! /usr/bin/grep -Fxq "$context" "$contexts"; then' \
  '          printf "%s\\n" "$context" >> "$contexts"' \
  '        fi' \
  '        ;;' \
  '      use)' \
  '        context="${3:?}"' \
  '        /usr/bin/grep -Fxq "$context" "$contexts"' \
  '        printf "%s\\n" "$context" > "$active"' \
  '        ;;' \
  '      *)' \
  '        printf "Unexpected fake docker context command: %s\\n" "$*" >&2' \
  '        exit 2' \
  '        ;;' \
  '    esac' \
  '    ;;' \
  '  info)' \
  '    [[ -s "$active" ]]' \
  '    printf "Server: fake Lima engine (%s)\\n" "$(/bin/cat "$active")"' \
  '    ;;' \
  '  *)' \
  '    printf "Unexpected fake docker command: %s\\n" "$*" >&2' \
  '    exit 2' \
  '    ;;' \
  'esac' > "$fake_bin/docker"

printf '%s\n' \
  '#!/bin/bash' \
  'set -euo pipefail' \
  'printf "brew %s\\n" "$*" >> "${FAKE_BREW_LOG:?}"' \
  'printf "brew %s\\n" "$*" >> "${FAKE_EVENT_LOG:?}"' \
  '[[ "${1:-}" == install ]]' > "$fake_bin/brew"

printf '%s\n' \
  '#!/bin/bash' \
  'printf "%s\\n" "${FAKE_UNAME_SYSTEM:-Darwin}"' > "$fake_bin/uname"

printf '%s\n' \
  '#!/bin/bash' \
  'exit 0' > "$fake_bin/rsync"

chmod 755 "$fake_bin/limactl" "$fake_bin/docker" "$fake_bin/brew" \
  "$fake_bin/uname" "$fake_bin/rsync"
export PATH="$fake_bin:/usr/bin:/bin"

if [[ -n "$real_limactl" ]]; then
  validation_output="$tmp_dir/limactl-validate.log"
  if ! "$real_limactl" validate "$repo_dir/lima/dev.yaml" \
      "$repo_dir/lima/agent.yaml" >"$validation_output" 2>&1; then
    printf '%s\n' 'limactl validate output:' >&2
    /bin/cat "$validation_output" >&2
    fail_assertion 'Lima configurations are rejected by limactl validate'
  fi
else
  printf '%s\n' 'SKIP: limactl is unavailable; YAML validation was not run.' >&2
fi

prepare_case install
install_output="$case_dir/output"
run_success "$install_output" "$repo_dir/scripts/lima_install.sh" || true
install_text="$(/bin/cat "$install_output")"
assert_log_line "$FAKE_BREW_LOG" 'brew install lima docker docker-compose' \
  'host installation requests the Lima and Docker packages'
assert_log_empty "$FAKE_LIMA_LOG" \
  'host installation does not start or inspect a VM'
assert_contains "$install_text" 'No VM was started.' \
  'host installation reports that no VM was started'

prepare_case install-non-macos
export FAKE_UNAME_SYSTEM=Linux
install_output="$case_dir/output"
if "$repo_dir/scripts/lima_install.sh" >"$install_output" 2>&1; then
  fail_assertion 'host installation rejects a non-macOS host'
fi
install_text="$(/bin/cat "$install_output")"
assert_contains "$install_text" 'requires macOS' \
  'non-macOS installation explains the platform requirement'
assert_log_empty "$FAKE_BREW_LOG" \
  'non-macOS installation does not invoke Homebrew'

prepare_case create-fresh
create_output="$case_dir/output"
run_success "$create_output" "$repo_dir/scripts/lima_create.sh" dev || true
create_text="$(/bin/cat "$create_output")"
assert_log_line "$FAKE_LIMA_LOG" \
  "limactl start --name=dev $repo_dir/lima/dev.yaml" \
  'creating a missing dev VM uses the dev configuration'
assert_log_line "$FAKE_LIMA_LOG" 'limactl stop dev' \
  'a newly provisioned dev VM is stopped for hostagent refresh'
assert_log_line "$FAKE_LIMA_LOG" 'limactl start dev' \
  'a newly provisioned dev VM is started again after refresh'
assert_contains "$create_text" 'Lima instance is ready: dev' \
  'dev creation reports a ready instance'

prepare_case create-existing
printf '%s\n' dev > "$FAKE_LIMA_STATE"
create_output="$case_dir/output"
run_success "$create_output" "$repo_dir/scripts/lima_create.sh" dev || true
assert_log_line "$FAKE_LIMA_LOG" 'limactl start dev' \
  'an existing dev VM is started'
assert_log_line_absent "$FAKE_LIMA_LOG" \
  "limactl start --name=dev $repo_dir/lima/dev.yaml" \
  'an existing dev VM is not recreated'
assert_log_line_absent "$FAKE_LIMA_LOG" 'limactl stop dev' \
  'an existing dev VM is not restarted for provisioning refresh'

prepare_case create-agent
create_output="$case_dir/output"
run_success "$create_output" "$repo_dir/scripts/lima_create.sh" agent || true
assert_log_line "$FAKE_LIMA_LOG" \
  "limactl start --name=agent $repo_dir/lima/agent.yaml" \
  'creating an agent VM uses the agent configuration'
assert_contains "$(/bin/cat "$create_output")" 'Lima instance is ready: agent' \
  'agent creation reports a ready instance'

prepare_case context-create
printf '%s\n' dev > "$FAKE_LIMA_STATE"
context_output="$case_dir/output"
run_success "$context_output" "$repo_dir/scripts/lima_docker_context.sh" dev || true
context_text="$(/bin/cat "$context_output")"
assert_log_line "$FAKE_DOCKER_LOG" 'docker context inspect lima-dev' \
  'context setup checks whether the named context exists'
assert_log_line "$FAKE_DOCKER_LOG" \
  'docker context create lima-dev --docker host=unix:///tmp/fake-lima/dev/sock/docker.sock' \
  'context setup creates a missing context with the forwarded socket'
assert_log_line "$FAKE_DOCKER_LOG" 'docker context use lima-dev' \
  'context setup selects the named context'
assert_log_line "$FAKE_DOCKER_LOG" 'docker info' \
  'context setup verifies Docker health'
assert_contains "$context_text" \
  'Docker context is active and healthy: lima-dev -> dev' \
  'new context setup reports a healthy context'

prepare_case context-update
printf '%s\n' dev > "$FAKE_LIMA_STATE"
printf '%s\n' lima-dev > "$FAKE_DOCKER_CONTEXTS"
context_output="$case_dir/output"
run_success "$context_output" "$repo_dir/scripts/lima_docker_context.sh" dev || true
assert_log_line "$FAKE_DOCKER_LOG" \
  'docker context update lima-dev --docker host=unix:///tmp/fake-lima/dev/sock/docker.sock' \
  'context setup updates an existing context with the forwarded socket'
assert_log_line_absent "$FAKE_DOCKER_LOG" \
  'docker context create lima-dev --docker host=unix:///tmp/fake-lima/dev/sock/docker.sock' \
  'existing context setup does not create a duplicate context'

prepare_case context-missing-instance
context_output="$case_dir/output"
if "$repo_dir/scripts/lima_docker_context.sh" dev >"$context_output" 2>&1; then
  fail_assertion 'context setup rejects a missing Lima instance'
fi
assert_contains "$(/bin/cat "$context_output")" \
  'Lima instance does not exist: dev' \
  'missing-instance context setup explains the failure'
assert_log_empty "$FAKE_DOCKER_LOG" \
  'missing-instance context setup does not invoke Docker'

prepare_case lifecycle
printf '%s\n' dev > "$FAKE_LIMA_STATE"
lifecycle_output="$case_dir/output"
run_success "$lifecycle_output" "$repo_dir/scripts/lima_lifecycle.sh" status dev || true
assert_log_line "$FAKE_LIMA_LOG" 'limactl list dev' \
  'lifecycle status queries the selected instance'
assert_contains "$(/bin/cat "$lifecycle_output")" dev \
  'lifecycle status reports the selected instance'
run_success "$lifecycle_output" "$repo_dir/scripts/lima_lifecycle.sh" stop dev || true
assert_log_line "$FAKE_LIMA_LOG" 'limactl stop dev' \
  'lifecycle stop stops the selected instance'
run_success "$lifecycle_output" "$repo_dir/scripts/lima_lifecycle.sh" autostart dev || true
assert_log_line "$FAKE_LIMA_LOG" \
  'limactl autostart enable --condition=login dev' \
  'lifecycle autostart registers the selected instance'

prepare_case lifecycle-destroy
printf '%s\n' dev > "$FAKE_LIMA_STATE"
lifecycle_output="$case_dir/output"
printf '%s\n' dev | "$repo_dir/scripts/lima_lifecycle.sh" destroy dev \
  >"$lifecycle_output" 2>&1 || fail_assertion 'confirmed lifecycle destroy succeeds'
assert_log_line "$FAKE_LIMA_LOG" 'limactl delete dev' \
  'lifecycle destroy deletes only after matching confirmation'

prepare_case lifecycle-destroy-abort
printf '%s\n' dev > "$FAKE_LIMA_STATE"
lifecycle_output="$case_dir/output"
if printf '%s\n' no | "$repo_dir/scripts/lima_lifecycle.sh" destroy dev \
    >"$lifecycle_output" 2>&1; then
  fail_assertion 'lifecycle destroy rejects a non-matching confirmation'
fi
assert_log_line_absent "$FAKE_LIMA_LOG" 'limactl delete dev' \
  'aborted lifecycle destroy does not delete the instance'
assert_contains "$(/bin/cat "$lifecycle_output")" 'Aborted' \
  'aborted lifecycle destroy reports that no deletion occurred'

prepare_case init
init_output="$case_dir/output"
run_success "$init_output" "$repo_dir/lima_init.sh" || true
init_text="$(/bin/cat "$init_output")"
assert_log_line "$FAKE_BREW_LOG" 'brew install lima docker docker-compose' \
  'initialization installs host prerequisites'
assert_log_line "$FAKE_LIMA_LOG" \
  "limactl start --name=dev $repo_dir/lima/dev.yaml" \
  'initialization creates the dev VM'
assert_log_line "$FAKE_DOCKER_LOG" \
  'docker context create lima-dev --docker host=unix:///tmp/fake-lima/dev/sock/docker.sock' \
  'initialization configures the Lima Docker context'
assert_log_line "$FAKE_LIMA_LOG" \
  'limactl autostart enable --condition=login dev' \
  'initialization enables dev autostart'
assert_event_order "$FAKE_EVENT_LOG" \
  'brew install lima docker docker-compose' \
  "limactl start --name=dev $repo_dir/lima/dev.yaml" \
  'initialization installs prerequisites before creating the VM'
assert_event_order "$FAKE_EVENT_LOG" \
  "limactl start --name=dev $repo_dir/lima/dev.yaml" \
  'docker context create lima-dev --docker host=unix:///tmp/fake-lima/dev/sock/docker.sock' \
  'initialization creates the VM before configuring Docker'
assert_event_order "$FAKE_EVENT_LOG" \
  'docker info' \
  'limactl autostart enable --condition=login dev' \
  'initialization verifies Docker before enabling autostart'
assert_contains "$init_text" 'Lima init: dev environment is ready' \
  'initialization reports a ready dev environment'

if (( failures > 0 )); then
  printf 'FAIL: %d Lima behavior assertion(s) failed.\n' "$failures" >&2
  exit 1
fi

printf '%s\n' 'PASS: Lima behavior'

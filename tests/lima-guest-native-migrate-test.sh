#!/bin/bash

set -euo pipefail

readonly test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly repo_dir="$(cd -- "$test_dir/.." && pwd -P)"
readonly tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

readonly fake_home="$tmp_dir/home"
readonly fake_bin="$tmp_dir/bin"
readonly command_log="$tmp_dir/commands.log"
readonly live_config="$fake_home/.lima/dev/lima.yaml"
mkdir -p "$(dirname -- "$live_config")" "$fake_bin"
printf '%s\n' 'legacy-live-config' > "$live_config"

cat > "$fake_bin/uname" <<'EOF'
#!/bin/bash
printf '%s\n' Darwin
EOF

cat > "$fake_bin/limactl" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'limactl %s\n' "$*" >> "${LIMA_MIGRATION_TEST_LOG:?}"
if [[ "${1:-}" == list && "${2:-}" == --format ]]; then
  printf '%s\n' dev
elif [[ "${1:-}" == list && "${2:-}" == dev && "${3:-}" == --format=unix://* ]]; then
  printf '%s\n' 'unix:///tmp/fake-lima/dev/sock/docker.sock'
elif [[ "${1:-}" == edit ]]; then
  printf '%s\n' 'edited-live-config' > "${LIMA_MIGRATION_TEST_CONFIG:?}"
elif [[ -n "${LIMA_MIGRATION_TEST_FAIL_ON:-}" && "$*" == *"$LIMA_MIGRATION_TEST_FAIL_ON"* ]]; then
  exit 1
fi
EOF

cat > "$fake_bin/docker" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'docker %s\n' "$*" >> "${LIMA_MIGRATION_TEST_LOG:?}"
case "$*" in
  'context inspect lima-dev') exit 0 ;;
esac
EOF

chmod 755 "$fake_bin/uname" "$fake_bin/limactl" "$fake_bin/docker"

HOME="$fake_home" \
PATH="$fake_bin:/usr/bin:/bin" \
LIMA_MIGRATION_TIMESTAMP='20260904-120000' \
LIMA_MIGRATION_TEST_LOG="$command_log" \
LIMA_MIGRATION_TEST_CONFIG="$live_config" \
  "$repo_dir/scripts/lima_guest_native_migrate.sh"

readonly backup="$fake_home/.lima/dev/config-backups/lima.yaml.20260904-120000"
[[ -f "$backup" ]] || fail 'live Lima configuration was not backed up'
grep -Fqx 'legacy-live-config' "$backup" || fail 'configuration backup changed content'
grep -Fq 'limactl stop dev' "$command_log" || fail 'VM was not stopped before editing'
grep -Fq 'del(.env.CODEX_HOME)' "$command_log" || fail 'legacy CODEX_HOME was not removed'
grep -Fq 'del(.env.TMPDIR)' "$command_log" || fail 'legacy TMPDIR was not removed'
grep -Fq '.ssh.forwardAgent = true' "$command_log" || fail 'SSH agent forwarding was not enabled'
grep -Fq 'location": "~/.cider"' "$command_log" || fail 'Cider-only mount was not configured'
grep -Fq 'lima_guest_layout.sh' "$command_log" || fail 'guest-native layout was not applied'
grep -Fq 'lima_codex_update.sh --guest' "$command_log" || fail 'guest Codex was not refreshed'
grep -Fq 'docker context update lima-dev' "$command_log" || fail 'macOS Docker context was not refreshed'
grep -Fq 'docker context use lima-dev' "$command_log" || fail 'macOS Docker context was not selected'

stop_line="$(grep -nF 'limactl stop dev' "$command_log" | head -1 | cut -d: -f1)"
edit_line="$(grep -nF 'limactl edit --tty=false dev' "$command_log" | head -1 | cut -d: -f1)"
start_line="$(grep -nF 'limactl start dev' "$command_log" | tail -1 | cut -d: -f1)"
[[ "$stop_line" -lt "$edit_line" && "$edit_line" -lt "$start_line" ]] || \
  fail 'VM configuration was not edited while the VM was stopped'

printf '%s\n' 'legacy-live-config' > "$live_config"
: > "$command_log"
if HOME="$fake_home" \
  PATH="$fake_bin:/usr/bin:/bin" \
  LIMA_MIGRATION_TIMESTAMP='20260904-120001' \
  LIMA_MIGRATION_TEST_LOG="$command_log" \
  LIMA_MIGRATION_TEST_CONFIG="$live_config" \
  LIMA_MIGRATION_TEST_FAIL_ON='lima_guest_layout.sh' \
    "$repo_dir/scripts/lima_guest_native_migrate.sh" >/dev/null 2>&1; then
  fail 'migration unexpectedly succeeded after guest layout failure'
fi
[[ "$(cat "$live_config")" == 'legacy-live-config' ]] || \
  fail 'failed pre-commit migration did not restore the live configuration'
[[ -f "$fake_home/.lima/dev/config-backups/lima.yaml.20260904-120001" ]] || \
  fail 'failed migration did not retain its configuration backup'
[[ "$(grep -Fc 'limactl start dev' "$command_log")" -ge 2 ]] || \
  fail 'failed migration did not restart the VM with the restored configuration'

printf '%s\n' 'PASS: existing Lima dev guest-native migration'

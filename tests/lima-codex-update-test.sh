#!/bin/bash

set -euo pipefail

readonly test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly repo_dir="$(cd -- "$test_dir/.." && pwd -P)"
readonly updater="$repo_dir/scripts/lima_codex_update.sh"
readonly tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

readonly guest_home="$tmp_dir/guest-home"
readonly shared_codex="$tmp_dir/shared-host-codex"
readonly fake_bin="$tmp_dir/bin"
readonly installer="$tmp_dir/installer.sh"
readonly command_log="$tmp_dir/codex.log"
readonly installer_env="$tmp_dir/installer.env"

mkdir -p "$guest_home" "$shared_codex" "$fake_bin"
printf '%s\n' 'host-state-must-remain' > "$shared_codex/marker"

cat > "$fake_bin/uname" <<'EOF'
#!/bin/bash
printf '%s\n' Linux
EOF

cat > "$fake_bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
destination=''
while (( $# > 0 )); do
  case "$1" in
    -o) destination="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$destination" ]]
cp "${LIMA_CODEX_TEST_INSTALLER:?}" "$destination"
EOF

cat > "$installer" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'CODEX_HOME=%s\n' "${CODEX_HOME:-}" > "${LIMA_CODEX_TEST_INSTALLER_ENV:?}"
release="$HOME/.codex/packages/standalone/releases/test-aarch64-unknown-linux-musl"
mkdir -p "$release/bin" "$HOME/.codex/packages/standalone" "$HOME/.local/bin"
cat > "$release/bin/codex" <<'INNER'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "${LIMA_CODEX_TEST_LOG:?}"
if [[ "$*" == 'app-server daemon bootstrap --remote-control' && \
      "${LIMA_CODEX_TEST_UNMANAGED:-}" == 1 ]]; then
  printf '%s\n' 'Error: app server is running but is not managed by codex app-server daemon' >&2
  exit 1
fi
case "$*" in
  '--version') printf '%s\n' 'codex-cli test' ;;
  'app-server daemon version') printf '%s\n' '{"status":"running","cliVersion":"test"}' ;;
esac
INNER
chmod 755 "$release/bin/codex"
ln -sfn "$release" "$HOME/.codex/packages/standalone/current"
ln -sfn "$release/bin/codex" "$HOME/.local/bin/codex"
EOF

chmod 755 "$fake_bin/uname" "$fake_bin/curl" "$installer"

HOME="$guest_home" \
CODEX_HOME="$shared_codex" \
PATH="$fake_bin:/usr/bin:/bin" \
LIMA_CODEX_TEST_INSTALLER="$installer" \
LIMA_CODEX_TEST_INSTALLER_ENV="$installer_env" \
LIMA_CODEX_TEST_LOG="$command_log" \
  "$updater" --guest

[[ -x "$guest_home/.codex/packages/standalone/current/bin/codex" ]] || \
  fail 'guest-local Codex release was not installed'
grep -Fqx 'CODEX_HOME=' "$installer_env" || \
  fail 'installer inherited the legacy shared CODEX_HOME'
grep -Fqx 'app-server daemon bootstrap --remote-control' "$command_log" || \
  fail 'guest Codex daemon was not bootstrapped for SSH remote control'
grep -Fqx 'app-server daemon version' "$command_log" || \
  fail 'guest Codex daemon version was not verified'
[[ "$(cat "$shared_codex/marker")" == 'host-state-must-remain' ]] || \
  fail 'shared macOS Codex state was modified'

HOME="$guest_home" \
CODEX_HOME="$shared_codex" \
PATH="$fake_bin:/usr/bin:/bin" \
LIMA_CODEX_TEST_INSTALLER="$installer" \
LIMA_CODEX_TEST_INSTALLER_ENV="$installer_env" \
LIMA_CODEX_TEST_LOG="$command_log" \
LIMA_CODEX_TEST_UNMANAGED=1 \
  "$updater" --guest

printf '%s\n' 'PASS: Lima guest-local Codex update'

#!/bin/bash
set -euo pipefail

readonly codex_home='/Users/blesscat/.codex'
readonly runtime_root='/var/lib/codex-lima'
readonly linux_install_root='/home/blesscat.guest/.local/share/codex-linux'
readonly guest_user='blesscat'

find_runnable_codex() {
  local release="$1"
  local candidate

  for candidate in "$release/codex" "$release/bin/codex"; do
    if [[ -x "$candidate" ]] && "$candidate" --version >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

find_latest_release() {
  local releases_root="$1"
  local candidate
  local latest=''

  while IFS= read -r candidate; do
    if find_runnable_codex "$candidate" >/dev/null; then
      latest="$candidate"
    fi
  done < <(
    find "$releases_root" \
      -mindepth 1 \
      -maxdepth 1 \
      -type d \
      -name '*-aarch64-unknown-linux-musl' \
      -print 2>/dev/null | LC_ALL=C sort -V
  )

  [[ -n "$latest" ]] || return 1
  printf '%s\n' "$latest"
}

wait_for_directory() {
  local directory="$1"
  local attempt

  for attempt in $(seq 1 60); do
    if [[ -d "$directory" ]]; then
      return 0
    fi
    sleep 1
  done

  printf 'Codex Lima overlay: directory did not appear: %s\n' "$directory" >&2
  return 1
}

for directory in \
  "$codex_home" \
  "$codex_home/packages/standalone" \
  "$codex_home/app-server-control" \
  "$codex_home/app-server-daemon"; do
  wait_for_directory "$directory"
done

install -d -m 0755 "$runtime_root"
install -d -o "$guest_user" -g "$guest_user" -m 0700 \
  /home/blesscat.guest/.local/state/codex-tmp
install -d -o "$guest_user" -g "$guest_user" -m 0700 \
  "$runtime_root/standalone" \
  "$runtime_root/standalone/releases" \
  "$runtime_root/app-server-control" \
  "$runtime_root/app-server-daemon"

# Keep the release selected by the official installer. Only repair a missing or
# unusable current link, preferring installer-managed releases over the legacy
# guest-local seed used when this overlay was first introduced.
if find_runnable_codex "$runtime_root/standalone/current" >/dev/null; then
  :
elif linux_release="$(find_latest_release "$runtime_root/standalone/releases")"; then
  ln -sfn "$linux_release" "$runtime_root/standalone/current"
elif linux_release="$(find_latest_release "$linux_install_root")"; then
  ln -sfn "$linux_release" "$runtime_root/standalone/current"
else
  printf '%s\n' \
    'Codex Lima overlay: no Linux Codex release is installed yet.' \
    'Run ~/.cider/scripts/lima_codex_update.sh on macOS to install one.' >&2
fi

for mapping in \
  "$runtime_root/standalone:$codex_home/packages/standalone" \
  "$runtime_root/app-server-control:$codex_home/app-server-control" \
  "$runtime_root/app-server-daemon:$codex_home/app-server-daemon"; do
  source_path="${mapping%%:*}"
  target_path="${mapping#*:}"
  if ! mountpoint -q "$target_path"; then
    mount --bind "$source_path" "$target_path"
  fi
done

printf 'Codex Lima overlay: Linux runtime mounted at %s\n' "$codex_home"

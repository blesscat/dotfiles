#!/bin/zsh

set -u

: "${CIDER_TEST_NIX_CAPTURE:?CIDER_TEST_NIX_CAPTURE is required}"
: "${CIDER_TEST_NIX_SYSTEM_ROOT:?CIDER_TEST_NIX_SYSTEM_ROOT is required}"
: "${CIDER_TEST_NIX_COMMAND:?CIDER_TEST_NIX_COMMAND is required}"

/usr/bin/printf 'STEP=system-installer\n' >> "$CIDER_TEST_NIX_CAPTURE"
for argument in "$@"; do
  /usr/bin/printf 'ARG=%s\n' "$argument" >> "$CIDER_TEST_NIX_CAPTURE"
done
/usr/bin/printf 'END\n' >> "$CIDER_TEST_NIX_CAPTURE"

if (( ${CIDER_TEST_INSTALLER_EXIT:-0} != 0 )); then
  exit "$CIDER_TEST_INSTALLER_EXIT"
fi
if [[ "${CIDER_TEST_PROFILE_MODE:-present}" == 'missing' ]]; then
  exit 0
fi

nix_profile="$CIDER_TEST_NIX_SYSTEM_ROOT/nix/var/nix/profiles/default"
/bin/mkdir -p "$nix_profile/bin" "$nix_profile/etc/profile.d"
/bin/ln -sf "$CIDER_TEST_NIX_COMMAND" "$nix_profile/bin/nix"
/usr/bin/printf 'export PATH="%s/bin:$PATH"\n' "$nix_profile" \
  > "$nix_profile/etc/profile.d/nix-daemon.sh"

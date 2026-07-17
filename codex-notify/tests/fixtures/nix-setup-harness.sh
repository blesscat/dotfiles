#!/usr/bin/env bash

set -u

fixture_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly fixture_dir
readonly repo_dir="$(cd -- "$fixture_dir/../../.." && pwd -P)"
readonly test_system_root="${1:?system root is required}"
harness_status=1

# Test-only dependency injection calls the shared implementation directly.
# Production scripts never consume this root from the environment.
# shellcheck source=scripts/nix_setup_lib.sh
source "$repo_dir/scripts/nix_setup_lib.sh"

if cider_nix_setup_main "$test_system_root"; then
  harness_status=0
  /usr/bin/printf 'HARNESS_NIX=%s\n' "$(command -v nix 2>/dev/null || true)" \
    >> "$CIDER_TEST_NIX_CAPTURE"
else
  harness_status=$?
fi

unset -f cider_nix_install_package cider_nix_setup_main
exit "$harness_status"

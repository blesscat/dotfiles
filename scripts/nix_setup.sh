#!/usr/bin/env bash

set -euo pipefail

# The production entrypoint always loads its repository-owned implementation
# and always passes the real system root. Test dependency injection belongs in
# the isolated harness, not in inherited production environment variables.
# shellcheck source=scripts/nix_setup_lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/nix_setup_lib.sh"

if cider_nix_setup_main ''; then
  cider_nix_status=0
else
  cider_nix_status=$?
fi

unset -f cider_nix_install_package cider_nix_setup_main
return "$cider_nix_status" 2>/dev/null || exit "$cider_nix_status"

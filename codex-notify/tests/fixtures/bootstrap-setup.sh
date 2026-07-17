#!/bin/bash

set -u

if [[ "${CODEX_TEST_REQUIRE_NIX_ACTIVE:-0}" == '1' && \
    "${CODEX_TEST_NIX_ACTIVE:-0}" != '1' ]]; then
  exit 41
fi

/usr/bin/printf 'STEP=setup\nEND\n' >> "$CODEX_TEST_BOOTSTRAP_CAPTURE"

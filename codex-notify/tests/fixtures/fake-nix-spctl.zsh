#!/bin/zsh

set -u

: "${CIDER_TEST_NIX_CAPTURE:?CIDER_TEST_NIX_CAPTURE is required}"

/usr/bin/printf 'STEP=spctl\n' >> "$CIDER_TEST_NIX_CAPTURE"
for argument in "$@"; do
  /usr/bin/printf 'ARG=%s\n' "$argument" >> "$CIDER_TEST_NIX_CAPTURE"
done
/usr/bin/printf 'END\n' >> "$CIDER_TEST_NIX_CAPTURE"

if (( ${CIDER_TEST_SPCTL_EXIT:-0} != 0 )); then
  print -u2 'fixture package assessment failed'
  exit "$CIDER_TEST_SPCTL_EXIT"
fi

if [[ "${CIDER_TEST_TEAM_ID:-X3JQ4VPJZ6}" != 'missing' ]]; then
  print -u2 \
    "origin=Developer ID Installer: Determinate Systems, Inc. (${CIDER_TEST_TEAM_ID:-X3JQ4VPJZ6})"
else
  print -u2 'accepted package without a parseable origin'
fi

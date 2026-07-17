#!/bin/zsh

set -u

: "${CIDER_TEST_NIX_CAPTURE:?CIDER_TEST_NIX_CAPTURE is required}"

/usr/bin/printf 'STEP=sudo\n' >> "$CIDER_TEST_NIX_CAPTURE"
for argument in "$@"; do
  /usr/bin/printf 'ARG=%s\n' "$argument" >> "$CIDER_TEST_NIX_CAPTURE"
done
/usr/bin/printf 'END\n' >> "$CIDER_TEST_NIX_CAPTURE"

if (( ${CIDER_TEST_SUDO_EXIT:-0} != 0 )); then
  exit "$CIDER_TEST_SUDO_EXIT"
fi

"$@"

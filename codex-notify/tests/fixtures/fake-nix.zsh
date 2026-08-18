#!/bin/zsh

set -u

: "${YAZELIX_TEST_NIX_CAPTURE:?YAZELIX_TEST_NIX_CAPTURE is required}"
/usr/bin/printf '%s\n' "$@" > "$YAZELIX_TEST_NIX_CAPTURE"

count_file="${YAZELIX_TEST_NIX_CAPTURE}.count"
typeset -i call_count=0
if [[ -r "$count_file" ]]; then
  call_count="$(<"$count_file")"
fi
(( call_count += 1 ))
/usr/bin/printf '%d\n' "$call_count" > "$count_file"

if (( call_count == 1 )) && \
    [[ -n "${YAZELIX_TEST_NIX_FIRST_EXIT:-}" ]]; then
  exit "$YAZELIX_TEST_NIX_FIRST_EXIT"
fi

exit "${YAZELIX_TEST_NIX_EXIT:-0}"

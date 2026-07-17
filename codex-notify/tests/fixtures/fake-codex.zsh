#!/bin/zsh

set -u

if [[ -n "${CODEX_TEST_CODEX_CAPTURE:-}" ]]; then
  /usr/bin/printf 'CALL\n' >> "$CODEX_TEST_CODEX_CAPTURE"
  /usr/bin/printf 'CODEX_HOME=%s\n' "${CODEX_HOME:-}" \
    >> "$CODEX_TEST_CODEX_CAPTURE"
  /usr/bin/printf 'ARG=%s\n' "$@" >> "$CODEX_TEST_CODEX_CAPTURE"
fi

if [[ -n "${CODEX_TEST_REAL_CODEX_HOME:-}" \
    && "${CODEX_HOME:-}" == "$CODEX_TEST_REAL_CODEX_HOME" ]]; then
  print -u2 'fake codex: doctor read the active CODEX_HOME instead of a candidate'
  exit 90
fi

candidate="${CODEX_HOME:-}/config.toml"
if [[ ! -f "$candidate" ]]; then
  print -u2 "fake codex: candidate config is missing: $candidate"
  exit 91
fi

if [[ -n "${CODEX_TEST_CODEX_REQUIRE:-}" ]] \
    && ! /usr/bin/grep -Fq -- "$CODEX_TEST_CODEX_REQUIRE" "$candidate"; then
  print -u2 'fake codex: candidate config does not contain the required value'
  exit 92
fi

/usr/bin/printf '{"checks":{"config.load":{"status":"%s"}}}\n' \
  "${CODEX_TEST_CODEX_STATUS:-ok}"
exit "${CODEX_TEST_CODEX_EXIT:-0}"

#!/bin/zsh

set -u

if [[ -n "${CODEX_TEST_CODESIGN_CAPTURE:-}" ]]; then
  /usr/bin/printf 'CALL\n' >> "$CODEX_TEST_CODESIGN_CAPTURE"
  /usr/bin/printf 'ARG=%s\n' "$@" >> "$CODEX_TEST_CODESIGN_CAPTURE"
fi

verify=0
for argument in "$@"; do
  if [[ "$argument" == '--verify' ]]; then
    verify=1
  fi
done

if (( verify )); then
  if [[ -n "${CODEX_TEST_CODESIGN_INVALID_PATH:-}" \
      && "${@[-1]}" == "$CODEX_TEST_CODESIGN_INVALID_PATH" ]]; then
    exit 1
  fi
  exit "${CODEX_TEST_CODESIGN_VERIFY_EXIT:-0}"
fi

exit "${CODEX_TEST_CODESIGN_SIGN_EXIT:-0}"

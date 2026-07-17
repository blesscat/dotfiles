#!/bin/zsh

set -u

: "${CIDER_TEST_NIX_CAPTURE:?CIDER_TEST_NIX_CAPTURE is required}"

/usr/bin/printf 'STEP=curl\n' >> "$CIDER_TEST_NIX_CAPTURE"

output_path=''
expect_output=0
for argument in "$@"; do
  /usr/bin/printf 'ARG=%s\n' "$argument" >> "$CIDER_TEST_NIX_CAPTURE"
  if (( expect_output == 1 )); then
    output_path="$argument"
    expect_output=0
  elif [[ "$argument" == '--output' ]]; then
    expect_output=1
  fi
done
/usr/bin/printf 'END\n' >> "$CIDER_TEST_NIX_CAPTURE"

if [[ -n "$output_path" ]]; then
  stage_mode="$(/usr/bin/stat -f '%Lp' "${output_path:h}")"
  /usr/bin/printf 'STAGE_MODE=%s\n' "$stage_mode" \
    >> "$CIDER_TEST_NIX_CAPTURE"
  /usr/bin/printf 'fixture package\n' > "$output_path"
fi

exit "${CIDER_TEST_CURL_EXIT:-0}"

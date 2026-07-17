#!/bin/zsh

set -u

readonly test_dir="${0:A:h}"
readonly repo_dir="${test_dir:h:h}"
readonly brewfile="$repo_dir/Brewfile"
readonly brew_bin="${CODEX_NOTIFY_TEST_BREW:-${commands[brew]-}}"

if [[ ! -f "$brewfile" ]]; then
  print -u2 "FAIL: Brewfile is missing: $brewfile"
  exit 1
fi
if [[ -z "$brew_bin" || ! -x "$brew_bin" ]]; then
  print -u2 'FAIL: brew is required for Brewfile contract validation'
  exit 1
fi

readonly tmp_dir="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "$tmp_dir"' EXIT HUP INT TERM

/usr/bin/printf '%s\n' \
  bash \
  zlib \
  openssl \
  cmake \
  ctags \
  ssh-copy-id \
  ripgrep \
  fzf \
  node \
  git \
  lazygit \
  wget \
  neovim \
  helix \
  mosh \
  unzip \
  yazi \
  fish \
  starship \
  zoxide \
  atuin \
  pnpm \
  zellij \
  jq \
  terminal-notifier \
  | /usr/bin/sort > "$tmp_dir/expected-formulas"

/usr/bin/printf '%s\n' \
  daisydisk \
  scroll-reverser \
  warp \
  ghostty \
  | /usr/bin/sort > "$tmp_dir/expected-casks"

/usr/bin/env HOMEBREW_NO_AUTO_UPDATE=1 \
  "$brew_bin" bundle list --file="$brewfile" --formula \
  | /usr/bin/sort > "$tmp_dir/actual-formulas" || exit 1
/usr/bin/env HOMEBREW_NO_AUTO_UPDATE=1 \
  "$brew_bin" bundle list --file="$brewfile" --cask \
  | /usr/bin/sort > "$tmp_dir/actual-casks" || exit 1
/usr/bin/env HOMEBREW_NO_AUTO_UPDATE=1 \
  "$brew_bin" bundle list --file="$brewfile" --tap \
  | /usr/bin/sort > "$tmp_dir/actual-taps" || exit 1

failures=0
if ! /usr/bin/cmp -s \
    "$tmp_dir/expected-formulas" "$tmp_dir/actual-formulas"; then
  print -u2 'FAIL: Brewfile formula set differs from the approved contract'
  /usr/bin/diff -u \
    "$tmp_dir/expected-formulas" "$tmp_dir/actual-formulas" >&2
  failures=1
fi
if ! /usr/bin/cmp -s \
    "$tmp_dir/expected-casks" "$tmp_dir/actual-casks"; then
  print -u2 'FAIL: Brewfile cask set differs from the approved contract'
  /usr/bin/diff -u \
    "$tmp_dir/expected-casks" "$tmp_dir/actual-casks" >&2
  failures=1
fi
if [[ -s "$tmp_dir/actual-taps" ]]; then
  print -u2 'FAIL: Brewfile must not declare taps'
  failures=1
fi

(( failures == 0 )) || exit 1
print 'PASS: Brewfile dependency contract'

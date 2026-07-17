#!/usr/bin/env bash

cider_nix_install_package() (
  set -euo pipefail

  local system_root="$1"
  local curl_bin="$system_root/usr/bin/curl"
  local spctl_bin="$system_root/usr/sbin/spctl"
  local sudo_bin="$system_root/usr/bin/sudo"
  local installer_bin="$system_root/usr/sbin/installer"
  local package_url='https://install.determinate.systems/determinate-pkg/stable/Universal'
  local stage_dir=''
  local package_path=''
  local assessment=''
  local team_id=''

  for required_command in \
    "$curl_bin" \
    "$spctl_bin" \
    "$sudo_bin" \
    "$installer_bin"; do
    if [[ ! -x "$required_command" ]]; then
      /usr/bin/printf 'Determinate Nix setup: required command is unavailable: %s\n' \
        "$required_command" >&2
      exit 1
    fi
  done

  umask 077
  if ! stage_dir="$(
    /usr/bin/mktemp -d "${TMPDIR:-/tmp}/cider-nix.XXXXXX"
  )"; then
    /usr/bin/printf '%s\n' \
      'Determinate Nix setup: temporary directory creation failed.' >&2
    exit 1
  fi
  trap '/bin/rm -rf "$stage_dir"' EXIT HUP INT TERM
  if ! /bin/chmod 700 "$stage_dir"; then
    /usr/bin/printf '%s\n' \
      'Determinate Nix setup: temporary directory hardening failed.' >&2
    exit 1
  fi
  package_path="$stage_dir/Determinate.pkg"

  if ! "$curl_bin" \
      --proto '=https' \
      --proto-redir '=https' \
      --tlsv1.2 \
      --fail \
      --silent \
      --show-error \
      --location \
      "$package_url" \
      --output "$package_path"; then
    /usr/bin/printf '%s\n' \
      'Determinate Nix setup: package download failed.' >&2
    exit 1
  fi

  if ! assessment="$(
    "$spctl_bin" -a -vv -t install "$package_path" 2>&1
  )"; then
    /usr/bin/printf '%s\n' "$assessment" >&2
    /usr/bin/printf '%s\n' \
      'Determinate Nix setup: package assessment failed.' >&2
    exit 1
  fi

  team_id="$(
    /usr/bin/printf '%s\n' "$assessment" \
      | /usr/bin/sed -n \
        's/.*origin=.*(\([A-Z0-9][A-Z0-9]*\)).*/\1/p' \
      | /usr/bin/head -n 1
  )"
  if [[ "$team_id" != 'X3JQ4VPJZ6' ]]; then
    /usr/bin/printf \
      'Determinate Nix setup: unexpected package Team ID: %s\n' \
      "${team_id:-unavailable}" >&2
    exit 1
  fi

  if ! "$sudo_bin" "$installer_bin" \
      -verboseR \
      -pkg "$package_path" \
      -target /; then
    /usr/bin/printf '%s\n' \
      'Determinate Nix setup: system package installation failed.' >&2
    exit 1
  fi
)

cider_nix_setup_main() {
  local system_root="${1:-}"
  local nix_bin=''
  local nix_version=''
  local answer=''
  local profile_script=''

  system_root="${system_root%/}"
  nix_bin="$(command -v nix 2>/dev/null || true)"
  if [[ -n "$nix_bin" && -x "$nix_bin" ]]; then
    if ! nix_version="$("$nix_bin" --version)" || \
        [[ -z "$nix_version" ]]; then
      /usr/bin/printf '%s\n' \
        'Determinate Nix setup: existing Nix version check failed.' >&2
      return 1
    fi
    /usr/bin/printf 'Nix is already available: %s\n' "$nix_version"
    return 0
  fi

  /usr/bin/printf '%s\n' \
    'Determinate Nix creates /nix and installs a system daemon.' \
    'Installation requires administrator authorization.'

  while true; do
    /usr/bin/printf 'Install Determinate Nix now? [y/N] ' >&2
    if ! IFS= read -r answer; then
      answer=''
    fi

    case "$answer" in
      y|Y|yes|Yes|YES|yEs|yeS|YEs|YeS)
        break
        ;;
      ''|n|N|no|No|NO|nO)
        /usr/bin/printf '%s\n' \
          'Determinate Nix installation skipped; Yazelix will be deferred.'
        return 0
        ;;
      *)
        /usr/bin/printf '%s\n' 'Please answer yes or no.' >&2
        ;;
    esac
  done

  if ! cider_nix_install_package "$system_root"; then
    /usr/bin/printf '%s\n' \
      'Determinate Nix setup: installation failed.' >&2
    return 1
  fi

  profile_script="$system_root/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  if [[ ! -r "$profile_script" ]]; then
    /usr/bin/printf 'Determinate Nix setup: environment profile is unavailable: %s\n' \
      "$profile_script" >&2
    return 1
  fi

  # shellcheck disable=SC1090
  if ! source "$profile_script"; then
    /usr/bin/printf '%s\n' \
      'Determinate Nix setup: environment activation failed.' >&2
    return 1
  fi

  nix_bin="$(command -v nix 2>/dev/null || true)"
  if [[ -z "$nix_bin" || ! -x "$nix_bin" ]]; then
    /usr/bin/printf '%s\n' \
      'Determinate Nix setup: nix is unavailable after installation.' >&2
    return 1
  fi
  if ! nix_version="$("$nix_bin" --version)" || \
      [[ -z "$nix_version" ]]; then
    /usr/bin/printf '%s\n' \
      'Determinate Nix setup: installed Nix version check failed.' >&2
    return 1
  fi
  if ! "$nix_bin" flake --help >/dev/null; then
    /usr/bin/printf '%s\n' \
      'Determinate Nix setup: flakes verification failed.' >&2
    return 1
  fi

  /usr/bin/printf 'Determinate Nix installed and verified: %s\n' \
    "$nix_version"
}

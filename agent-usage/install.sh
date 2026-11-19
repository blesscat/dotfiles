#!/usr/bin/env bash
# Install the agent usage page as a background service that starts by itself and restarts on failure.
#   Linux: systemd user service  ~/.config/systemd/user/agent-usage.service
#   macOS: launchd agent         ~/Library/LaunchAgents/local.cider.agent-usage.plist
#
#   ./install.sh             install or update, then (re)start
#   ./install.sh uninstall   stop and remove the service; keeps ~/.config/agent-usage and the caches
#
# Optional settings, written into the service when set while running this script:
#   AGENT_USAGE_HOST, AGENT_USAGE_PORT, AGENT_USAGE_NODE, AGENT_USAGE_CODEX   (see server.py)
#   AGENT_USAGE_PYTHON                                      python to run the server with
# Example: AGENT_USAGE_PORT=8791 ./install.sh
set -euo pipefail

readonly module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly server="$module_dir/server.py"
readonly config_dir="$HOME/.config/agent-usage"
readonly keys_file="$config_dir/keys"
readonly unit_name=agent-usage.service
readonly unit_file="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$unit_name"
readonly label=local.cider.agent-usage
readonly plist="$HOME/Library/LaunchAgents/$label.plist"
readonly log_file="$HOME/Library/Logs/agent-usage.log"
readonly setting_names="AGENT_USAGE_HOST AGENT_USAGE_PORT AGENT_USAGE_NODE AGENT_USAGE_CODEX"
# Paths and settings are written into the unit / plist as they are, so keep them to plain characters.
readonly safe_value='^[A-Za-z0-9._/@+:-]+$'
readonly safe_path='^[A-Za-z0-9._/@+ -]+$'

die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

find_python() {
  local candidate
  if [ -n "${AGENT_USAGE_PYTHON:-}" ]; then
    set -- "$AGENT_USAGE_PYTHON"
  elif [ "$(uname -s)" = Darwin ]; then
    # /usr/bin/python3 is a stub that asks to install the Command Line Tools when they are missing.
    set -- /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3 "$(command -v python3 || true)"
  else
    set -- /usr/bin/python3 "$(command -v python3 || true)"
  fi
  for candidate in "$@"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    if "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 8))' 2>/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

check_settings() {
  local name value
  for name in $setting_names; do
    value="${!name:-}"
    [ -z "$value" ] || [[ "$value" =~ $safe_value ]] || die "$name has characters this script does not write into a service: $value"
  done
}

create_keys_file() {
  mkdir -p "$config_dir"
  chmod 700 "$config_dir"
  [ -e "$keys_file" ] && return 0
  (
    umask 077
    cat > "$keys_file" <<'EOF'
# API keys for the agent usage page (~/.cider/agent-usage). Only you can read this file (600).
# Save after filling them in; the page updates within 10 seconds, no service restart needed.
# ZCode: optional. Leave blank to use the key ZCode is already signed in with (decrypted via the system keyring)
ZAI_API_KEY=
# MiniMax: optional. Leave blank to use the token from mcode's login (only while it is still valid, never refreshed)
MINIMAX_API_KEY=
EOF
  )
  echo "Created $keys_file"
}

install_systemd() {
  local python=$1 name value tmp
  command -v systemctl >/dev/null || die "systemctl not found"
  mkdir -p "$(dirname "$unit_file")"
  tmp="$unit_file.tmp"
  {
    echo "# Written by $module_dir/install.sh; change that and run it again instead of editing this."
    echo "[Unit]"
    echo "Description=Agent usage page (remaining quota of Claude, Codex, ZCode, MiniMax and Antigravity)"
    echo
    echo "[Service]"
    echo "ExecStart=\"$python\" -I \"$server\""
    for name in $setting_names; do
      value="${!name:-}"
      [ -z "$value" ] || echo "Environment=$name=$value"
    done
    echo "Restart=always"
    echo "RestartSec=10"
    echo
    echo "[Install]"
    echo "WantedBy=default.target"
  } > "$tmp"
  mv -f "$tmp" "$unit_file"
  systemctl --user daemon-reload
  systemctl --user enable "$unit_name" >/dev/null
  systemctl --user restart "$unit_name"
  echo "Installed $unit_file"
  echo "Status: systemctl --user status agent-usage    Logs: journalctl --user -u agent-usage -f"
  local user
  user=$(id -un)
  if [ "$(loginctl show-user "$user" -p Linger --value 2>/dev/null || true)" != yes ]; then
    echo "Note: it runs only while you are logged in. To start it at boot and keep it running after logout:"
    echo "  loginctl enable-linger $user"
  fi
}

uninstall_systemd() {
  command -v systemctl >/dev/null || die "systemctl not found"
  systemctl --user disable --now "$unit_name" 2>/dev/null || true
  rm -f "$unit_file"
  systemctl --user daemon-reload
  echo "Removed $unit_name"
}

plist_string() { printf '    <string>%s</string>\n' "$1"; }

install_launchd() {
  local python=$1 domain name value tmp settings='' attempt
  domain="gui/$(id -u)"
  for name in $setting_names; do
    value="${!name:-}"
    [ -z "$value" ] || settings="$settings    <key>$name</key><string>$value</string>"$'\n'
  done
  mkdir -p "$(dirname "$plist")" "$(dirname "$log_file")"
  tmp="$plist.tmp"
  {
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- Written by $module_dir/install.sh; change that and run it again instead of editing this. -->
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
EOF
    plist_string "$python"
    plist_string "-I"
    plist_string "$server"
    echo "  </array>"
    if [ -n "$settings" ]; then
      echo "  <key>EnvironmentVariables</key>"
      echo "  <dict>"
      printf '%s' "$settings"
      echo "  </dict>"
    fi
    cat <<EOF
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardOutPath</key><string>$log_file</string>
  <key>StandardErrorPath</key><string>$log_file</string>
</dict>
</plist>
EOF
  } > "$tmp"
  plutil -lint "$tmp" >/dev/null || die "the generated plist is not valid: $tmp"
  mv -f "$tmp" "$plist"
  launchctl enable "$domain/$label"
  launchctl bootout "$domain/$label" 2>/dev/null || true
  # bootstrap fails while the previous copy is still shutting down, so give it a few tries.
  for attempt in 1 2 3 4 5; do
    launchctl bootstrap "$domain" "$plist" 2>/dev/null && break
    [ "$attempt" = 5 ] && die "launchctl bootstrap $domain $plist failed"
    sleep 1
  done
  echo "Installed $plist"
  echo "Status: launchctl print $domain/$label    Logs: tail -f $log_file"
}

uninstall_launchd() {
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  rm -f "$plist"
  echo "Removed $label"
}

main() {
  local action=${1:-install} os python
  os=$(uname -s)
  case "$os" in
    Linux|Darwin) ;;
    *) die "unsupported system: $os (Linux and macOS only)" ;;
  esac
  case "$action" in
    install) ;;
    uninstall)
      if [ "$os" = Darwin ]; then uninstall_launchd; else uninstall_systemd; fi
      return 0
      ;;
    *) die "usage: $0 [install|uninstall]" ;;
  esac

  [[ "$module_dir" =~ $safe_path ]] || die "move the repository to a path without special characters: $module_dir"
  python=$(find_python) || die "Python 3.8 or newer not found (set AGENT_USAGE_PYTHON to choose one)"
  [[ "$python" =~ $safe_path ]] || die "python path has special characters: $python"
  check_settings
  create_keys_file
  if [ "$os" = Darwin ]; then install_launchd "$python"; else install_systemd "$python"; fi
  echo "Python: $python"
  echo "The page listens on this machine's Tailscale address, port ${AGENT_USAGE_PORT:-8790}, unless AGENT_USAGE_HOST says otherwise."
}

main "$@"

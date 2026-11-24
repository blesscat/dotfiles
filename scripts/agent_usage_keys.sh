#!/usr/bin/env bash
# API keys for the Omarchy agents panel, kept in the GNOME keyring.
#
# The panel's Z.ai and MiniMax collectors read their keys from files, so this
# stores the keys in the keyring and writes those files from it. No key is
# kept in this repository.
#
#   ./scripts/agent_usage_keys.sh store zai       prompt for a key, save it in the keyring
#   ./scripts/agent_usage_keys.sh store minimax
#   ./scripts/agent_usage_keys.sh [apply]         write the collectors' files from the keyring
#
# Keyring entries: service=omarchy-agent-usage account=<zai|minimax>
set -euo pipefail

readonly service=omarchy-agent-usage
readonly config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

# <account>|<file the collector reads>|<JSON field that holds the key>
readonly -a targets=(
  "zai|$config_home/omarchy/agents/zai.json|apiKey"
  "minimax|${MMX_CONFIG_DIR:-$HOME/.mmx}/config.json|api_key"
)

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v secret-tool >/dev/null 2>&1 || die 'secret-tool not found (package libsecret).'
command -v jq >/dev/null 2>&1 || die 'jq is required.'

store() {
  local account="$1" entry known=0
  for entry in "${targets[@]}"; do
    [[ "${entry%%|*}" == "$account" ]] && known=1
  done
  (( known )) || die "unknown account '$account' (zai or minimax)"

  # secret-tool reads the secret from the terminal without echoing it.
  secret-tool store --label="Omarchy agent usage: $account" \
    service "$service" account "$account"
  printf 'Stored %s in the keyring. Run %s apply to write it out.\n' "$account" "$0"
}

apply() {
  local entry account rest file field key tmp written=0
  for entry in "${targets[@]}"; do
    account="${entry%%|*}"
    rest="${entry#*|}"
    file="${rest%|*}"
    field="${rest#*|}"

    if ! key="$(secret-tool lookup service "$service" account "$account" 2>/dev/null)" || [[ -z "$key" ]]; then
      printf '  missing %s (store it with: %s store %s)\n' "$account" "$0" "$account"
      continue
    fi

    mkdir -p "$(dirname "$file")"
    tmp="$(mktemp "$file.XXXXXX")"
    chmod 600 "$tmp"
    # Keep any other settings already in the file. The key goes through the
    # environment so it never appears in a process's arguments.
    if [[ -s "$file" ]] && jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
      KEY="$key" jq --arg f "$field" '.[$f] = env.KEY' "$file" > "$tmp"
    else
      KEY="$key" jq -n --arg f "$field" '{($f): env.KEY}' > "$tmp"
    fi
    mv "$tmp" "$file"
    printf '  wrote   %s\n' "$file"
    written=$((written + 1))
  done
  unset key

  if (( written )) && command -v omarchy-agent-usage-update >/dev/null 2>&1; then
    omarchy-agent-usage-update >/dev/null 2>&1 || true
  fi
}

case "${1:-apply}" in
  store) [[ $# -eq 2 ]] || die "usage: $0 store <zai|minimax>"; store "$2" ;;
  apply) apply ;;
  -h | --help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown command '$1' (store or apply)" ;;
esac

# Shared Bash adapter for the terminal background command.

terminal_bg() {
  local terminal_bg_home="${CIDER_HOME:-$HOME/.cider}"
  local terminal_bg_command="$terminal_bg_home/scripts/terminal-bg"

  if [ ! -x "$terminal_bg_command" ]; then
    printf 'terminal-bg: executable not found: %s\n' "$terminal_bg_command" >&2
    return 127
  fi

  "$terminal_bg_command" "$@"
}

alias bg-night='terminal_bg night'
alias bg-ocean='terminal_bg ocean'
alias bg-slate='terminal_bg slate'
alias bg-forest='terminal_bg forest'
alias bg-plum='terminal_bg plum'
alias bg-alert='terminal_bg alert'
alias bg-reset='terminal_bg reset'

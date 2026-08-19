# Shared Fish adapter for the terminal background command.

function terminal_bg
    set -l terminal_bg_home "$HOME/.cider"
    if set -q CIDER_HOME
        set terminal_bg_home "$CIDER_HOME"
    end

    set -l terminal_bg_command "$terminal_bg_home/scripts/terminal-bg"
    if not test -x "$terminal_bg_command"
        printf 'terminal-bg: executable not found: %s\n' "$terminal_bg_command" >&2
        return 127
    end

    "$terminal_bg_command" $argv
end

alias bg-night='terminal_bg night'
alias bg-ocean='terminal_bg ocean'
alias bg-slate='terminal_bg slate'
alias bg-forest='terminal_bg forest'
alias bg-plum='terminal_bg plum'
alias bg-alert='terminal_bg alert'
alias bg-reset='terminal_bg reset'

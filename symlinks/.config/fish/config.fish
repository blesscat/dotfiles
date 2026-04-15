# PATH
fish_add_path ~/.local/bin

# pnpm
set -gx PNPM_HOME "$HOME/Library/pnpm"
fish_add_path $PNPM_HOME

# lazygit
set -gx XDG_CONFIG_HOME "$HOME/.config"

# helix
set -gx EDITOR hx
set -gx VISUAL hx

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# OpenClaw completion
# source "/Users/blesscat/.openclaw/completions/openclaw.fish"

# Hermes aliases
alias hermes-opus='hermes chat --model claude-opus-4-6'
alias hermes-sonnet='hermes chat --model claude-sonnet-4-6'
alias hermes-haiku='hermes chat --model claude-haiku-4-5'
alias hermes-gpt54='hermes chat --model gpt-5.4'
alias vi='nvim'
alias lg='lazygit'
alias ls='eza -laah'

if status is-interactive
    # Commands to run in interactive sessions can go here
end

starship init fish | source
zoxide init fish | source
atuin init fish | source

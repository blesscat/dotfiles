# PATH
fish_add_path ~/.local/bin

# pnpm
set -gx PNPM_HOME /Users/blesscat/Library/pnpm
fish_add_path $PNPM_HOME

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# OpenClaw completion
source "/Users/blesscat/.openclaw/completions/openclaw.fish"

# Hermes aliases
alias hermes-opus='hermes chat --model claude-opus-4-6'
alias hermes-sonnet='hermes chat --model claude-sonnet-4-6'
alias hermes-haiku='hermes chat --model claude-haiku-4-5'
alias hermes-gpt54='hermes chat --model gpt-5.4'
alias vi='nvim'
alias lg='lazygit'

if status is-interactive
    # Commands to run in interactive sessions can go here
end

starship init fish | source

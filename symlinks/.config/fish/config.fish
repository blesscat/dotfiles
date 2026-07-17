# PATH
fish_add_path ~/.local/bin

# Node.js
set -g nvm_default_version v24.16.0

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

alias vi='nvim'
alias lg='lazygit'
# alias ls='eza -laah'

if status is-interactive
    # Commands to run in interactive sessions can go here
end

starship init fish | source
zoxide init fish | source
atuin init fish | source

# Auto use Node version from .nvmrc
source ~/.config/fish/load_nvm.fish

# Homebrew
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# PATH
export PATH="$HOME/.local/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# lazygit and other XDG-aware tools
export XDG_CONFIG_HOME="$HOME/.config"

# helix
export EDITOR=hx
export VISUAL=hx

alias vi='nvim'
alias lg='lazygit'

alias codex-innova='CODEX_HOME="$HOME/.codex-innova" codex'
alias codex-personal='CODEX_HOME="$HOME/.codex-personal" codex'

# Interactive-only tooling
if [[ -o interactive ]]; then
  # Node.js: switch versions from .nvmrc / .node-version on cd.
  command -v fnm >/dev/null && eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"

  command -v starship >/dev/null && eval "$(starship init zsh)"
  command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
  command -v atuin >/dev/null && eval "$(atuin init zsh)"

  # Cider terminal background shortcuts (bg-night, bg-ocean, ...).
  terminal_bg_file="${CIDER_HOME:-$HOME/.cider}/shell/terminal-bg.bash"
  [[ -r "$terminal_bg_file" ]] && source "$terminal_bg_file"
  unset terminal_bg_file
fi

# OrbStack: command-line tools and integration
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# Machine-local settings and secrets (API keys); not tracked in the repo.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

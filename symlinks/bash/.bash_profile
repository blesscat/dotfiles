# Optimized .bash_profile

# Basic PATH configuration (merged duplicate paths)
export PATH="$HOME/bin:/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# Development tools
export PATH="$HOME/flutter-sdk/bin:$HOME/android-sdk/cmdline-tools/latest/bin:$PATH"
export PATH="$HOME/.deno/bin:$HOME/go/bin:$HOME/.cabal/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
export PATH="/opt/homebrew/opt/libpq/bin:/opt/homebrew/opt/ruby@2.7/bin:$PATH"

# Environment variables
export PYENV_ROOT="$HOME/.pyenv"
export PIPENV_VENV_IN_PROJECT=1
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Simple aliases
alias la="ls -la"
alias ll="ls -l"
alias lg="lazygit"
alias vi="nvim"
alias vim="nvim"
alias glog="git log --pretty=format:'%h %s %an %cd' --graph"

# Remove time-consuming initialization
# eval "$(thefuck --alias)"  # Too slow, commented out

# RVM PATH (only set path, don't load functions)
export PATH="$PATH:$HOME/.rvm/bin"

# Windsurf
export PATH="/Users/bless/.codeium/windsurf/bin:$PATH"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"                                       # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion

# Auto use nvm default version
if [ -s "$NVM_DIR/nvm.sh" ]; then
    nvm use default >/dev/null 2>&1
fi
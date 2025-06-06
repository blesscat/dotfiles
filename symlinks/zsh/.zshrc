# Fast startup .zshrc

# Minimal Zim framework configuration
ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi

if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
  source ${ZIM_HOME}/zimfw.zsh init -q
fi
source ${ZIM_HOME}/init.zsh

# Basic Zsh configuration
setopt HIST_IGNORE_ALL_DUPS
bindkey -e
WORDCHARS=${WORDCHARS//[\/]}

# Load bash profile
[[ -r ~/.bash_profile ]] && source ~/.bash_profile

# Ensure correct Node.js version is used
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    source "$HOME/.nvm/nvm.sh"
    nvm use default >/dev/null 2>&1
fi

# Key bindings (simplified)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Lazy loading functions
pyenv() {
    unfunction pyenv
    eval "$(command pyenv init -)"
    pyenv "$@"
}

asdf() {
    unfunction asdf  
    source "$HOME/.asdf/asdf.sh"
    source "$HOME/.asdf/completions/asdf.bash"
    asdf "$@"
}

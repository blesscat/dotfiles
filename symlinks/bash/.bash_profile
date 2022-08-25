export PATH="$HOME/bin:$PATH"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

#pipenv
export PIPENV_VENV_IN_PROJECT=1

# fzf
# [ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Homebrew
export PATH="/usr/local/bin:$PATH"
export PATH="/usr/local/sbin:$PATH"

# Cask
export PATH="$HOME/.cask/bin:$PATH"

# ruby
export PATH="/usr/local/opt/ruby/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/ruby/lib"
export CPPFLAGS="-I/usr/local/opt/ruby/include"
export PKG_CONFIG_PATH="/usr/local/opt/ruby/lib/pkgconfig"

export PATH="/usr/local/opt/sphinx-doc/bin:$PATH"

# flutter
export PATH="$HOME/doc/flutter/bin:$PATH"
export PATH="/usr/local/mysql/bin:$PATH"

# ruby
export PATH="/usr/local/lib/ruby/gems/2.7.0/bin:$PATH"

# denon
export PATH="$HOME/.deno/bin:$PATH"

# server
export PATH="$HOME/.serve:$PATH"

# ImplicitCAD
export PATH="$HOME/.cabal/bin:$PATH"

# Alias
alias la="ls -la"
alias ll="ls -l"
alias vi="nvim"
alias neovide="neovide --multigrid"
# alias vim="nvim"
alias glog="git log --pretty=format:'%h %s %an %cd' --graph"
alias clearswp="rm ~/.local/share/nvim/swap/*.swp"
alias ibrew="arch -x86_64 brew"
alias ipyenv="arch -x86_64 pyenv"
eval "$(thefuck --alias)"
. "$HOME/.cargo/env"

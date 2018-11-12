[ -f ~/.bashrc ] && source ~/.bashrc

export PATH="$HOME/bin:$PATH"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

if which pyenv > /dev/null; then eval "$(pyenv init -)"; fi
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi
export PYENV_VIRTUALENV_DISABLE_PROMPT=1

# fzf
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

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


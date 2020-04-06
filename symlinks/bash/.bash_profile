[ -f ~/.bashrc ] && source ~/.bashrc

export PATH="$HOME/bin:$PATH"

# pyenv
# export PYENV_ROOT="$HOME/.pyenv"
# export PATH="$PYENV_ROOT/bin:$PATH"

#pipenv
export PIPENV_VENV_IN_PROJECT=1

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

export PATH="/usr/local/opt/sphinx-doc/bin:$PATH"

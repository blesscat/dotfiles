export PATH="$HOME/bin:$PATH"

### Homebrew
export PATH="/usr/local/bin:$PATH"
export PATH="/usr/local/sbin:$PATH"

### Cask
export PATH="$HOME/.cask/bin:$PATH"

### rvm
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
export PATH="/opt/local/lib:/usr/local/lib:$PATH"
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

### flutter
export PATH="$HOME/flutter-sdk/bin:$PATH"
export PATH="$HOME/android-sdk/cmdline-tools/latest/bin:$PATH"

### denon
export PATH="$HOME/.deno/bin:$PATH"

### server
export PATH="$HOME/.serve:$PATH"

### ImplicitCAD
export PATH="$HOME/.cabal/bin:$PATH"

### golang
export PATH="$HOME/go/bin:$PATH"

### Alias
alias la="ls -la"
alias ll="ls -l"
alias lg="lazygit"
alias vi="nvim"
alias vim="nvim"
alias neovide="neovide --multigrid"
alias nv="neovide"
alias glog="git log --pretty=format:'%h %s %an %cd' --graph"
alias clearswp="rm ~/.local/state/nvim/swap/*.swp"
alias ibrew="arch -x86_64 brew"
alias ipyenv="arch -x86_64 pyenv"
eval "$(thefuck --alias)"

### pnpm
export PATH="$HOME/.npm-global/bin:$PATH"

parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Global
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export PATH="$HOME/.yarn/bin:/usr/local/bin:$PATH"

# Alias
alias vi=/usr/bin/vim
alias la="ls -la"
alias ll="ls -l"
alias vi="nvim"
alias vim="nvim"
alias glog="git log --pretty=format:'%h %s %an %cd' --graph"
alias clearswp="rm ~/.vim/.swp/*.swp"
eval "$(thefuck --alias)"

# Colors
export GREP_OPTIONS='--color=auto'
export LS_OPTIONS='--color=auto'
export CLICOLOR='true'
export LSCOLORS="gxfxcxdxcxegedabagacad"
export PS1="\[\033[32m\]\w\[\033[33m\]\$(parse_git_branch)\[\033[00m\]$ "
# export PS1="\u@\h \[\033[32m\]\w\[\033[33m\]\$(parse_git_branch)\[\033[00m\]$ "

# [ -f ~/.fzf.bash ] && source ~/.fzf.bash

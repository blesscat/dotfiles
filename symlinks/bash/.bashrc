parse_git_branch() {
	git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Global
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export PATH="$HOME/.yarn/bin:/usr/local/bin:$PATH"

# Colors
export GREP_OPTIONS='--color=auto'
export LS_OPTIONS='--color=auto'
export CLICOLOR='true'
export LSCOLORS="gxfxcxdxcxegedabagacad"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# Cider terminal background shortcuts.
terminal_bg_file="${CIDER_HOME:-$HOME/.cider}/shell/terminal-bg.bash"
if [ -r "$terminal_bg_file" ]; then
  . "$terminal_bg_file"
fi
unset terminal_bg_file

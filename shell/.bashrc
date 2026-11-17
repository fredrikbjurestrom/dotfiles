# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Login shells load .profile through .bash_profile; other interactive shells
# need the same environment without depending on what the parent inherited.
if ! shopt -q login_shell && [ -r "$HOME/.profile" ]; then
  . "$HOME/.profile"
fi

[ -r "$HOME/.shrc" ] && . "$HOME/.shrc"

# Skip duplicate lines and lines starting with a space; append instead of overwriting.
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# Update LINES and COLUMNS after each command.
shopt -s checkwinsize

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Fallback for machines without starship.
PS1='\u@\h:\w\$ '

# Keep last: starship wraps PROMPT_COMMAND/PS1.
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

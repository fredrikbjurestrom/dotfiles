#!/usr/bin/zsh

# Login shells load .profile through .zprofile.
if [[ ! -o login ]] && [ -r "$HOME/.profile" ]; then
  . "$HOME/.profile"
fi

[ -r "$HOME/.shrc" ] && . "$HOME/.shrc"

autoload -Uz compinit && compinit -i

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

bindkey "^[[1;5D" backward-word
bindkey "^[[1;5C" forward-word

PROMPT_EOL_MARK=''

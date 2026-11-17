#!/usr/bin/zsh

# .profile is already loaded by .zshenv.
[ -r "$HOME/.shrc" ] && . "$HOME/.shrc"

# Zsh cannot save more lines than it keeps in memory, so the two limits must match.
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE

autoload -Uz compinit && compinit -i

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

bindkey "^[[1;5D" backward-word
bindkey "^[[1;5C" forward-word

PROMPT_EOL_MARK=''

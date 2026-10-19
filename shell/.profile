# Move a directory to the front without accumulating duplicate entries.
# Function arguments are local to the call; this also works in POSIX sh.
path_prepend() {
  set -- "$1" ":${PATH-}:"
  while [ "$2" != "${2#*":$1:"}" ]; do
    set -- "$1" "${2%%":$1:"*}:${2#*":$1:"}"
  done
  set -- "$1" "${2#:}"
  set -- "$1" "${2%:}"
  PATH="$1${2:+:$2}"
}
path_append() { case ":$PATH:" in *":$1:"*) ;; *) PATH="${PATH:+$PATH:}$1";; esac; }

path_prepend "$HOME/.opencode/bin"
path_prepend "$HOME/.dotnet/tools"
path_prepend "$HOME/.local/bin"
export PATH

export EDITOR="nvim"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export FUNCTIONS_CORE_TOOLS_TELEMETRY_OPTOUT=1

# export XDG_CONFIG_HOME="$HOME/.config"
# export XDG_CACHE_HOME="$HOME/.cache"
# export XDG_DATA_HOME="$HOME/.local/share"

# Zsh already initializes Cargo in .zshenv, including non-interactive shells.
if [ -z "${ZSH_VERSION-}" ] && [ -r "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

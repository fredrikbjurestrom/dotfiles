# Every Zsh reads this file, so scripts, editors and agents get the same
# environment as the terminal. .profile is idempotent and runs no external commands.
[ -r "$HOME/.profile" ] && . "$HOME/.profile"

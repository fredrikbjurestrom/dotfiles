# Keep Rust available to non-interactive Zsh, without requiring an installation.
if [ -r "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

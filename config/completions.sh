# Tab completion for the commands in bin/ (interactive bash and zsh only).
if [ -n "${BASH_VERSION:-}" ]; then
    . "$RE_EXT_HOME/completions/re-extended.bash"
elif [ -n "${ZSH_VERSION:-}" ]; then
    . "$RE_EXT_HOME/completions/re-extended.zsh"
fi

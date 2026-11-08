# Tab completion for the commands in bin/ (interactive bash and zsh only).
# Loads completions/common.<shell> first, then every other completions/*.<shell>
# file, one per topic (android.bash, ...).
if [ -n "${BASH_VERSION:-}" ]; then
    _re_ext=bash
elif [ -n "${ZSH_VERSION:-}" ]; then
    _re_ext=zsh
fi
if [ -n "${_re_ext:-}" ]; then
    . "$RE_EXT_HOME/completions/common.$_re_ext"
    for _re_comp in "$RE_EXT_HOME"/completions/*."$_re_ext"; do
        case "$_re_comp" in */common."$_re_ext") continue ;; esac
        if [ -r "$_re_comp" ]; then . "$_re_comp"; fi
    done
fi
unset _re_ext _re_comp

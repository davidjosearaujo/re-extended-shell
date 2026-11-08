# Core module: zsh completion setup for every module's completions.zsh (loaded
# first), and completion for re-doctor.

# compdef only exists once the completion system is initialised. Most setups
# (oh-my-zsh, prezto, ...) do that before this file is sourced; if not, do it.
if (( ! $+functions[compdef] )); then
    autoload -Uz compinit && compinit -i
fi

_re_re_doctor() {
    local -a modules
    modules=( $RE_EXT_HOME/modules/*/doctor.sh(N:h:t) )
    modules=( ${modules:#core} )
    _arguments '(- *)'{-h,--help}'[show help]' "*:module:(${modules})"
}
compdef _re_re_doctor re-doctor

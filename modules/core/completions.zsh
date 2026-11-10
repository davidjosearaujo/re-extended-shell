# Core module: zsh completion setup for every module's completions.zsh (loaded
# first), and completion for re-doctor and re-extended-shell.

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

_re_re_extended_shell() {
    local -a modules
    modules=( $RE_EXT_HOME/modules/*(N/:t) )
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(- *)--version[show the version]' \
        '*'{-m,--module}"[only show this module]:module:(${modules})" \
        '--modules[the modules]' \
        '--commands[the commands]' \
        '--envs[the settings (environment variables)]' \
        '--paths[the PATH entries]' \
        '--aliases[the aliases]' \
        '--functions[the shell functions]' \
        '--data[downloads and caches]'
}
compdef _re_re_extended_shell re-extended-shell

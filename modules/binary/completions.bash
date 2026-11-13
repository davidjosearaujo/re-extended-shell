# shellcheck shell=bash
# Binary module: bash tab completion (helpers in modules/core/completions.bash).

_re_complete_bin_triage() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -n|--min-length|-l|--limit) COMPREPLY=(); return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-n --min-length -l --limit --decode --xor -h --help"
    else
        _re_reply_files ""
    fi
}

_re_complete_proto_extract() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -o|--output) _re_reply_dirs; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-o --output -f --force --all -h --help"
    else
        _re_reply_files ""
    fi
}

_re_complete_so_exports() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -g|--grep|-l|--limit) COMPREPLY=(); return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-g --grep -l --limit --all --imports -h --help"
    else
        _re_reply_files ""
    fi
}

_re_complete_crypto_find() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        --min-confidence) _re_reply_words "low medium high"; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "--min-confidence -h --help"
    else
        _re_reply_files ""
    fi
}

_re_complete_crypto_libs() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-h --help"
    else
        _re_reply_files ""
    fi
}

complete -F _re_complete_bin_triage bin-triage
complete -F _re_complete_proto_extract proto-extract
complete -F _re_complete_so_exports so-exports
complete -F _re_complete_crypto_find crypto-find
complete -F _re_complete_crypto_libs crypto-libs

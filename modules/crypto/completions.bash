# shellcheck shell=bash
# Crypto module: bash tab completion (helpers in modules/core/completions.bash).

_re_complete_file_hash() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        --algo) _re_reply_words "md5 sha1 sha224 sha256 sha384 sha512 sha3-256 sha3-512 blake2b crc32"; return ;;
        --check) COMPREPLY=(); return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-r --recursive --algo --dups --check --vt -h --help"
    else
        _re_reply_files ""
    fi
}

_re_complete_cert_info() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -o|--output) _re_reply_files ""; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-o --output -f --force --leaf --pem -h --help"
    else
        _re_reply_files "cer|crt|pem|der|cert|ca"
    fi
}

_re_complete_jwt_decode() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        --secret) COMPREPLY=(); return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "--secret -h --help"
    else
        COMPREPLY=()
    fi
}

complete -F _re_complete_file_hash file-hash
complete -F _re_complete_cert_info cert-info
complete -F _re_complete_jwt_decode jwt-decode

# shellcheck shell=bash
# Core module: bash completion helpers for every module's completions.bash
# (loaded first), and completion for re-doctor.

# Valid in bash 3.2 (macOS's /bin/bash): no mapfile or ${var,,}.

# COMPREPLY = words from $1 matching the current word
_re_reply_words() {
    local w
    COMPREPLY=()
    while IFS= read -r w; do
        COMPREPLY+=("$w")
    done < <(compgen -W "$1" -- "$cur")
}

# COMPREPLY = directories + files whose extension is in $1 (e.g. "xapk|zip"),
# matched case-insensitively
_re_reply_files() {
    local f re="\\.($1)\$" nocase
    shopt -q nocasematch && nocase=1
    shopt -s nocasematch
    COMPREPLY=()
    while IFS= read -r f; do
        if [ -d "$f" ] || [ -z "$1" ] || [[ "$f" =~ $re ]]; then
            COMPREPLY+=("$f")
        fi
    done < <(compgen -f -- "$cur")
    [ -n "$nocase" ] || shopt -u nocasematch
    compopt -o filenames 2>/dev/null
}

# COMPREPLY = directories matching the current word
_re_reply_dirs() {
    local d
    COMPREPLY=()
    while IFS= read -r d; do
        COMPREPLY+=("$d")
    done < <(compgen -d -- "$cur")
    compopt -o filenames 2>/dev/null
}

_re_complete_re_doctor() {
    local cur=${COMP_WORDS[COMP_CWORD]} f modules=""
    for f in "$RE_EXT_HOME"/modules/*/doctor.sh; do
        f=${f%/doctor.sh}; f=${f##*/}
        [ "$f" = core ] || modules="$modules $f"
    done
    _re_reply_words "$modules -h --help"
}
complete -F _re_complete_re_doctor re-doctor

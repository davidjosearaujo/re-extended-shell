# shellcheck shell=bash
# Bash completion helpers shared by every completions/<topic>.bash file.
# Loaded first by config/completions.sh.

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

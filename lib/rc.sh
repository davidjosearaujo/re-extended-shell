# shellcheck shell=bash
# RE Extended Bash - rc file hook handling, shared by ./install and ./uninstall.
# Expects REPO to be set to the repo root before it's sourced.

RE_MARKER="# Installed by RE Extended Bash"
MAIN="$REPO/re_extended_bash_main"

# The file a bash login shell reads: the first of these that exists
bash_login_file() {
    local F
    for F in "$HOME/.bash_profile" "$HOME/.bash_login"; do
        if [ -f "$F" ]; then echo "$F"; return 0; fi
    done
    return 1
}

# Prints the rc file(s) to hook for a shell, one per line, main one first.
# macOS terminals start bash as a login shell, which reads ~/.bash_profile (or
# ~/.bash_login) and not ~/.bashrc, so there that file is hooked too, unless it
# already sources ~/.bashrc. With --all (for uninstall) every file the hook may
# have gone into is listed.
# Usage: rc_for [--all] bash|zsh
rc_for() {
    local ALL="" LOGIN
    if [ "$1" = "--all" ]; then ALL=1; shift; fi
    case "$1" in
        bash)
            echo "$HOME/.bashrc"
            if [ -n "$ALL" ]; then
                echo "$HOME/.bash_profile"
                echo "$HOME/.bash_login"
            elif [ "$(uname -s)" = Darwin ] && LOGIN=$(bash_login_file) \
                && ! grep -qE '^[^#]*(source|\.)[[:space:]].*\.bashrc' "$LOGIN"; then
                echo "$LOGIN"
            fi
            ;;
        zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
    esac
}

# macOS: with no ~/.bash_profile, bash login shells would never read ~/.bashrc.
# Creates the conventional one, keeping ~/.profile loaded (a new
# ~/.bash_profile would otherwise hide it).
ensure_bash_profile() {
    [ "$(uname -s)" = Darwin ] || return 0
    bash_login_file >/dev/null && return 0
    cat >"$HOME/.bash_profile" <<'EOF2'
# Created by RE Extended Bash: macOS terminals start bash as a login shell,
# which reads this file and not ~/.bashrc.
[ -f ~/.profile ] && . ~/.profile
[ -f ~/.bashrc ] && . ~/.bashrc
EOF2
    echo "  $HOME/.bash_profile: created, loads ~/.profile and ~/.bashrc"
}

# Single-quote a path for the rc file (valid in bash and zsh)
quote() {
    local q="'\\''"
    printf "'%s'" "${1//\'/$q}"
}
RE_LINE="[ -f $(quote "$MAIN") ] && . $(quote "$MAIN")"
export RE_MARKER RE_LINE

# Rewrites an rc file to stdout: replaces (or, with RE_MODE=uninstall, drops) an
# existing hook and any line sourcing the old single-file 'bash_custom', keeping
# its position in the file. A fresh install is appended at the end.
rewrite_rc() {
    awk '
        BEGIN {
            marker = ENVIRON["RE_MARKER"]; line = ENVIRON["RE_LINE"]
            install = (ENVIRON["RE_MODE"] != "uninstall")
            legacy = "^[ \t]*(source|\\.)[ \t]+[\"'\'']?[^\"'\'']*/bash_custom[\"'\'']?[ \t]*$"
        }
        function hook() {
            if (install && !done) { print marker; print line }
            done = 1
        }
        after_marker {
            after_marker = 0
            if ($0 ~ /re_extended_bash_main/) next
        }
        $0 == marker { hook(); after_marker = 1; next }
        $0 ~ legacy  { hook(); next }
        { print }
        END { if (install && !done) { if (NR) print ""; print marker; print line } }
    ' "$1"
}

# Usage: update_rc install|uninstall <rc file>
update_rc() {
    local MODE="$1" RC="$2" TMP
    if [ ! -f "$RC" ]; then
        [ "$MODE" = uninstall ] && return 0
        touch "$RC"
    fi
    TMP=$(mktemp)
    RE_MODE="$MODE" rewrite_rc "$RC" >"$TMP"
    if cmp -s "$RC" "$TMP"; then
        rm -f "$TMP"
        [ "$MODE" = install ] && echo "  $RC: already up to date"
        return 0
    fi
    cp -p "$RC" "$RC.re-ext.bak"
    cat "$TMP" >"$RC"   # write in place: keeps symlinks (dotfile managers) and permissions
    rm -f "$TMP"
    if [ "$MODE" = uninstall ]; then
        echo "  $RC: hook removed (backup: $RC.re-ext.bak)"
    else
        echo "  $RC: hooked (backup: $RC.re-ext.bak)"
    fi
}

# The old installer also wrote to ~/.profile; drop that without adding anything
clean_legacy_profile() {
    if [ -f "$HOME/.profile" ] && grep -qE '^[[:space:]]*(source|\.)[[:space:]]+.*/bash_custom' "$HOME/.profile"; then
        update_rc uninstall "$HOME/.profile"
    fi
}

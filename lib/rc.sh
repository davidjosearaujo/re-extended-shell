# shellcheck shell=bash
# RE Extended Bash - rc file hook handling, shared by ./install and ./uninstall.
# Expects REPO to be set to the repo root before it's sourced.

RE_MARKER="# Installed by RE Extended Bash"
MAIN="$REPO/re_extended_bash_main"

rc_for() {
    case "$1" in
        bash) echo "$HOME/.bashrc" ;;
        zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
    esac
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
        echo "  $RC: already up to date"
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

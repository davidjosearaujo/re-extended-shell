# shellcheck shell=bash
# Every command looks and behaves like the rest of the family: the same help
# layout, the same errors, a summary line, completions, a README entry, and
# settings declared in a manifest. See "Adding a module" in the README.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset

COMMANDS=()
for F in "$REPO"/modules/*/bin/*; do COMMANDS+=("$F"); done
COMMANDS+=("$REPO/install" "$REPO/uninstall")

# Prints what's wrong with a --help output ($1), for command $2, or nothing
help_problems() {
    awk -v cmd="$2" '
        NR == 1 && index($0, "Usage: " cmd) != 1 { print "the first line is not \"Usage: " cmd " ...\"" }
        NR > 1 && !blank && $0 == "" { blank = NR }
        NR > 1 && !blank && $0 !~ /^       / { print "line " NR " follows the Usage lines without a blank line" }
        /^[A-Z][A-Za-z ()/.]*:$/ { sect = $0; if ($0 == "Options:") opts = 1; next }
        $0 == "" { sect = ""; next }
        sect == "Options:" && /^  -/ {
            # where the description starts: after the option, its value, and 2+ spaces
            if (match($0, /^  -[^ ]*( [A-Z_.]+)?(, -[^ ]*( [A-Z_.]+)?)?  +/)) {
                c = RLENGTH
                if (col && c != col) print "option \"" $0 "\" is not aligned with the others"
                col = c
            }
            if ($0 ~ /^  -h, --help +Show this help$/) help = 1
            next
        }
        sect == "Options:" && /^ +[^ ]/ {
            match($0, /^ +/)
            if (col && RLENGTH != col) print "continuation \"" $0 "\" is not aligned with the descriptions"
        }
        { last = $0 }
        END {
            if (!opts) print "no Options: section"
            if (!help) print "no \"-h, --help  Show this help\" line"
            if (last !~ /^RE Extended Shell .*\. All commands: re-extended-shell --commands$/) print "no family footer at the end"
        }' <<<"$1"
}

for F in "${COMMANDS[@]}"; do
    CMD=${F##*/}
    case "$F" in "$REPO/install"|"$REPO/uninstall") CMD="./$CMD" ;; esac

    run "$F" --help
    PROBLEMS=$(help_problems "$OUT" "$CMD")
    if [ "$RC" = 0 ] && [ -z "$PROBLEMS" ]; then
        pass "$CMD --help follows the family layout"
    else
        fail "$CMD --help follows the family layout" "exit code $RC" "$PROBLEMS"
    fi

    run "$F" --bogus
    if [ "$RC" != 0 ] && [ "$OUT" = "Error: unknown option: --bogus (see $CMD --help)" ]; then
        pass "$CMD rejects an unknown option the family way"
    else
        fail "$CMD rejects an unknown option the family way" "exit code $RC" "output: $OUT"
    fi

    case "$CMD" in ./*) continue ;; esac
    SUMMARY=$(sed -n 2p "$F")
    if [[ "$SUMMARY" =~ ^#\ [A-Z].*\.$ ]]; then
        pass "$CMD has a one-line summary on line 2"
    else
        fail "$CMD has a one-line summary on line 2" "line 2: $SUMMARY"
    fi
    if grep -qE "^complete -F [_a-z]+ $CMD\$" "$REPO"/modules/*/completions.bash \
            && grep -qE "^compdef [_a-z]+ $CMD\$" "$REPO"/modules/*/completions.zsh; then
        pass "$CMD has bash and zsh completion"
    else
        fail "$CMD has bash and zsh completion"
    fi
    grep -qF "\`$CMD" "$REPO/README.md" && pass "$CMD is in the README" || fail "$CMD is in the README"
    if grep -qE 'echo "Warning:' "$F"; then
        fail "$CMD prints warnings with re_warn"
    else
        pass "$CMD prints warnings with re_warn"
    fi
done

# --- Settings: declared once, in a manifest, and documented -------------------
core() { (cd "$REPO" && . modules/core/lib.sh && "$@"); }   # a core helper, in a subshell
SETTINGS=$(core re_settings)
NAMES=$(cut -d'|' -f2 <<<"$SETTINGS")
for M in "$REPO"/modules/*/; do
    M=${M%/}; M=${M##*/}
    [ -n "$(core re_module_about "$M")" ] \
        && pass "module $M has an about: line" || fail "module $M has an about: line"
done
while IFS='|' read -r M NAME _ DESC CMDS; do
    [ -n "$DESC" ] && pass "$NAME has a description" || fail "$NAME has a description"
    for C in $CMDS; do
        [ -x "$REPO/modules/"*"/bin/$C" ] 2>/dev/null || ls "$REPO"/modules/*/bin/"$C" >/dev/null 2>&1 \
            || fail "$NAME is used by an existing command" "no command $C"
    done
    grep -qE "^# export $NAME=" "$REPO/local.example/env.sh" \
        && pass "$NAME is in local.example/env.sh" || fail "$NAME is in local.example/env.sh"
    grep -qF "\`$NAME\`" "$REPO/README.md" && pass "$NAME is in the README" || fail "$NAME is in the README"
done <<<"$SETTINGS"
# Every setting the commands read with a default, and every one in
# local.example/env.sh, is declared
for NAME in $( (grep -rhoE '\$\{(RE_[A-Z0-9_]+|[A-Z0-9_]+_(HOME|JAR)|JADX[A-Z_]*):-' "$REPO"/modules/*/bin "$REPO"/modules/*/lib.sh | sed 's/^\${//; s/:-$//'
                grep -hoE '^# export [A-Z][A-Z0-9_]*=' "$REPO/local.example/env.sh" | sed 's/^# export //; s/=$//') | sort -u); do
    case "$NAME" in
        RE_EXT_HOME|TMPDIR|NO_COLOR|ANDROID_AVD_HOME|ANDROID_SDK_ROOT) continue ;;   # not settings of ours
    esac
    grep -qxF "$NAME" <<<"$NAMES" && pass "$NAME is declared in a manifest" || fail "$NAME is declared in a manifest"
done

# --- The shared error helpers --------------------------------------------------
run apk-patch
expect_rc 1 "a missing operand fails"
expect_out "Error: missing <file.apk>." "...says what's missing"
expect_out "Usage: apk-patch" "...shows the Usage line"
expect_out "Run 'apk-patch --help' for details." "...and points to --help"
expect_no_out "Options:" "...without the whole help"
run device-proxy on PHONE
expect_out "unexpected argument: PHONE (name the device with -s SERIAL)" "an unexpected argument can carry a hint"

done_testing

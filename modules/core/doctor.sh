# shellcheck shell=bash
# re-doctor checks of the core module: the shell hook, PATH, and ZAP.
# Sourced by core/bin/re-doctor, which provides the doc_* helpers.
# shellcheck disable=SC2154  # _re_shell_home and C_* come from bin/re-doctor

doc_section "RE Extended Shell"
doc_info "$RE_OS $(uname -m), bash $BASH_VERSION, repo $(doc_path "$RE_EXT_HOME")"

HOOKS=""
OTHER_HOOK=""
for RC in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.bash_login" "${ZDOTDIR:-$HOME}/.zshrc"; do
    if [ ! -f "$RC" ] || ! grep -q 're_extended_shell_main' "$RC"; then continue; fi
    if grep -qF "$RE_EXT_HOME/re_extended_shell_main" "$RC"; then
        HOOKS="$HOOKS $(doc_path "$RC")"
    else
        OTHER_HOOK="$OTHER_HOOK $(doc_path "$RC")"
    fi
done
if [ -n "$HOOKS" ]; then
    doc_ok "Hooked into:$HOOKS"
else
    doc_fail "Not hooked into any shell rc file" "Run: $(doc_path "$RE_EXT_HOME")/install"
fi
[ -z "$OTHER_HOOK" ] || doc_warn "Hook pointing at another copy of the repo in:$OTHER_HOOK" \
    "Run ./install from the copy you want to use, it updates the line in place."

if [ -z "$_re_shell_home" ]; then
    doc_warn "Not loaded in this shell" "Open a new shell (after ./install) so the settings and completions apply."
elif [ "$_re_shell_home" != "$RE_EXT_HOME" ]; then
    doc_warn "This shell loaded another copy: $(doc_path "$_re_shell_home")"
fi

MODULE_LIST="" OFF_PATH=""
for DIR in "$RE_EXT_HOME"/modules/*/; do
    DIR=${DIR%/}
    MODULE_LIST="$MODULE_LIST ${DIR##*/}"
    [ -d "$DIR/bin" ] || continue
    case ":$PATH:" in *":$DIR/bin:"*) ;; *) OFF_PATH="$OFF_PATH ${DIR##*/}" ;; esac
done
doc_info "Modules:$MODULE_LIST"
if [ -z "$OFF_PATH" ]; then
    doc_ok "Every module's commands are on PATH"
else
    doc_fail "Commands not on PATH for:$OFF_PATH" "Open a new shell after ./install."
fi
[ -d "$RE_EXT_HOME/local" ] || doc_warn "No local/ settings folder" "./install creates it."

doc_section "ZAP"
if [ ! -f "$RE_ZAP_CERT" ]; then
    doc_fail "No ZAP root CA at $(doc_path "$RE_ZAP_CERT")" \
        "Export it (ZAP: Tools > Options > Network > Server Certificates > Save) or set RE_ZAP_CERT."
elif ! command -v openssl >/dev/null 2>&1; then
    doc_fail "openssl not found, needed to read and convert the ZAP CA"
else
    FORM=""
    for F in PEM DER; do
        if openssl x509 -inform "$F" -in "$RE_ZAP_CERT" -noout >/dev/null 2>&1; then FORM=$F; break; fi
    done
    if [ -z "$FORM" ]; then
        doc_fail "$(doc_path "$RE_ZAP_CERT") is not a PEM or DER X.509 certificate"
    else
        NAME=$(openssl x509 -inform "$FORM" -in "$RE_ZAP_CERT" -noout -subject 2>/dev/null \
            | sed -n 's/.*CN *= *\([^,/]*\).*/\1/p')
        [ -n "$NAME" ] && NAME="'$NAME' "
        END=$(openssl x509 -inform "$FORM" -in "$RE_ZAP_CERT" -noout -enddate 2>/dev/null | sed 's/^notAfter=//')
        if ! openssl x509 -inform "$FORM" -in "$RE_ZAP_CERT" -noout -checkend 0 >/dev/null 2>&1; then
            doc_fail "ZAP CA expired on $END" "Generate a new one in ZAP (Server Certificates > Generate), then export it again."
        elif ! openssl x509 -inform "$FORM" -in "$RE_ZAP_CERT" -noout -checkend 2592000 >/dev/null 2>&1; then
            doc_warn "ZAP CA ${NAME}expires soon: $END"
        else
            doc_ok "ZAP CA ${NAME}($FORM, valid until $END)"
        fi
    fi
fi
if re_port_listening "$RE_ZAP_PORT"; then
    doc_ok "Something listens on port $RE_ZAP_PORT (RE_ZAP_PORT)"
else
    doc_warn "Nothing listens on port $RE_ZAP_PORT" "Start ZAP with its proxy on 127.0.0.1:$RE_ZAP_PORT, or set RE_ZAP_PORT in local/env.sh."
fi
doc_tool optional curl "the commands that download tools (xapk-merger, frida-server)" || true

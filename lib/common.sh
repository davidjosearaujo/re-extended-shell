# shellcheck shell=bash
# RE Extended Shell - helpers shared by every command in bin/, whatever the topic.
# Sourced by those scripts (always bash), never by your interactive shell.
# Topic-specific helpers live next to it (lib/android.sh, ...) and source this.
# Must stay valid in bash 3.2 (macOS's /bin/bash) and work with both GNU
# (Linux) and BSD (macOS) userland tools.

RE_EXT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

# Interception proxy, shared by any topic that routes traffic through ZAP.
# Export either of these (e.g. in local/env.sh) to override.
RE_ZAP_PORT="${RE_ZAP_PORT:-9090}"
RE_ZAP_CERT="${RE_ZAP_CERT:-$RE_EXT_HOME/certs/zap_root_ca.cer}"

re_die() {
    echo "Error: $*" >&2
    exit 1
}

re_require() {
    local tool
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 || re_die "'$tool' is required but not installed (or not on PATH)."
    done
}

RE_OS=$(uname -s)   # Linux, Darwin, ...

# Succeeds if something listens on TCP port $1 on this machine.
re_port_listening() {
    if command -v ss >/dev/null 2>&1; then
        [ -n "$(ss -Hltn "sport = :$1")" ]
    elif command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
    else
        netstat -an 2>/dev/null | awk -v p="$1" '
            toupper($NF) == "LISTEN" && $4 ~ ("[.:]" p "$") { found = 1 }
            END { exit !found }'
    fi
}

# Succeeds if process PID was started with an argument exactly equal to $2.
# Linux reads /proc (exact, even with spaces in arguments); elsewhere (macOS)
# 'ps' only gives the space-joined command line, so it matches whole words.
re_proc_has_arg() {
    local PID="$1" ARG="$2"
    if [ -r "/proc/$PID/cmdline" ]; then
        tr '\0' '\n' <"/proc/$PID/cmdline" 2>/dev/null | grep -qxF -- "$ARG"
    else
        ps -o args= -p "$PID" 2>/dev/null | tr ' ' '\n' | grep -qxF -- "$ARG"
    fi
}

# Prints the path of a GUI tool: on PATH, or (macOS) inside its .app bundle.
# Usage: re_find_gui_tool <command> <App name>   e.g. re_find_gui_tool wireshark Wireshark
re_find_gui_tool() {
    local APP
    if command -v "$1" >/dev/null 2>&1; then command -v "$1"; return 0; fi
    if [ "$RE_OS" = Darwin ]; then
        for APP in "/Applications/$2.app" "$HOME/Applications/$2.app"; do
            if [ -x "$APP/Contents/MacOS/$2" ]; then echo "$APP/Contents/MacOS/$2"; return 0; fi
        done
    fi
    return 1
}

# Exits with export instructions unless $RE_ZAP_CERT exists
re_require_zap_cert() {
    [ -f "$RE_ZAP_CERT" ] && return 0
    cat >&2 <<EOF
Error: ZAP root CA certificate not found at: $RE_ZAP_CERT
Export it from ZAP (Tools > Options > Network > Server Certificates > Save),
or from the command line with: zap.sh -cmd -certpubdump <file>
then save it to that path, or point RE_ZAP_CERT at it (e.g. in local/env.sh).
EOF
    exit 1
}

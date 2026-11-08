# shellcheck shell=bash
# RE Extended Shell - helpers shared by the commands of every module.
# Sourced by those scripts (always bash), never by your interactive shell.
# Each module's own helpers live in modules/<module>/lib.sh, which sources this.
# Must stay valid in bash 3.2 (macOS's /bin/bash) and work with both GNU
# (Linux) and BSD (macOS) userland tools.

RE_EXT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)

# Interception proxy, shared by any module that routes traffic through ZAP.
# Export either of these (e.g. in local/env.sh) to override.
RE_ZAP_PORT="${RE_ZAP_PORT:-9090}"
RE_ZAP_CERT="${RE_ZAP_CERT:-$RE_EXT_HOME/certs/zap_root_ca.cer}"

# Downloads and caches the commands keep outside the repo (removed by
# './uninstall --purge'). Each module uses its own subdirectory.
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_DATA_DIR="$HOME/.local/share/re-extended-shell"

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

# Downloads URL to DEST through DEST.part, so a failed or interrupted download
# never leaves a half-written file (or damages an existing one). Creates DEST's
# directory. Extra arguments go to curl (e.g. --progress-bar, -sS).
# Usage: re_download URL DEST [curl option]...
re_download() {
    local URL="$1" DEST="$2"
    shift 2
    re_require curl
    mkdir -p "$(dirname -- "$DEST")" || return 1
    if curl -fL "$@" -o "$DEST.part" "$URL"; then
        mv -f "$DEST.part" "$DEST"
    else
        rm -f "$DEST.part"
        return 1
    fi
}

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

# Succeeds if version $1 is lower than $2, comparing the leading numeric
# major.minor.patch parts (suffixes like "-dirty" are ignored).
# Usage: re_version_lt 2.7.0-dirty 2.9
re_version_lt() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        n = split(a, x, /[^0-9]+/); m = split(b, y, /[^0-9]+/)
        for (i = 1; i <= 3; i++) {
            if (x[i] + 0 < y[i] + 0) exit 0
            if (x[i] + 0 > y[i] + 0) exit 1
        }
        exit 1
    }'
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

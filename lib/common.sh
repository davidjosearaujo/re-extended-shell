# shellcheck shell=bash
# RE Extended Bash - helpers shared by the commands in bin/.
# Sourced by those scripts (always bash), never by your interactive shell.
# Must stay valid in bash 3.2 (macOS's /bin/bash) and work with both GNU
# (Linux) and BSD (macOS) userland tools.

RE_EXT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

# Settings: export any of these (e.g. in local/env.sh) to override.
RE_ZAP_PORT="${RE_ZAP_PORT:-9090}"
RE_ZAP_SNAPSHOT="${RE_ZAP_SNAPSHOT:-zap-ready}"
RE_ZAP_CERT="${RE_ZAP_CERT:-$RE_EXT_HOME/certs/zap_root_ca.cer}"
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_DEVICE_DIR="/data/local/tmp/re-ext"   # where files get pushed on the device

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

# Serials of connected, authorised devices. --physical skips emulators.
re_adb_devices() {
    if [ "${1:-}" = "--physical" ]; then
        adb devices | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ { print $1 }'
    else
        adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'
    fi
}

# Prints the serial to use: the given one if it's connected, otherwise the only
# connected device. Errors go to stderr.
# Usage: re_pick_device [--physical] <caller> [SERIAL]
re_pick_device() {
    local FILTER=""
    if [ "${1:-}" = "--physical" ]; then FILTER="--physical"; shift; fi
    local CALLER="$1" SERIAL="${2:-}" KIND="device"
    [ -n "$FILTER" ] && KIND="physical device"
    if [ -z "$SERIAL" ]; then
        local DEVICES=() LINE
        while IFS= read -r LINE; do
            [ -n "$LINE" ] && DEVICES+=("$LINE")
        done < <(re_adb_devices $FILTER)
        case "${#DEVICES[@]}" in
            0)  echo "Error: no $KIND connected (check 'adb devices' and that USB debugging is authorised)." >&2
                return 1 ;;
            1)  SERIAL="${DEVICES[0]}" ;;
            *)  echo "Error: several devices connected, pick one with: $CALLER <SERIAL>" >&2
                printf '  %s\n' "${DEVICES[@]}" >&2
                return 1 ;;
        esac
    fi
    if [ "$(adb -s "$SERIAL" get-state 2>/dev/null)" != "device" ]; then
        echo "Error: device '$SERIAL' is not connected or not authorised (see 'adb devices')." >&2
        return 1
    fi
    echo "$SERIAL"
}

# Converts $RE_ZAP_CERT (PEM or DER) into the <subject_hash_old>.0 file Android
# expects, inside OUT_DIR. Sets RE_CERT_HASH and RE_CERT_FILE.
# Usage: re_prepare_cert OUT_DIR
re_prepare_cert() {
    local OUT_DIR="$1" FORM
    if [ ! -f "$RE_ZAP_CERT" ]; then
        cat >&2 <<EOF
Error: ZAP root CA certificate not found at: $RE_ZAP_CERT
Export it from ZAP (Tools > Options > Network > Server Certificates > Save),
or from the command line with: zap.sh -cmd -certpubdump <file>
then save it to that path, or point RE_ZAP_CERT at it (e.g. in local/env.sh).
EOF
        exit 1
    fi
    re_require openssl
    for FORM in PEM DER; do
        if RE_CERT_HASH=$(openssl x509 -inform "$FORM" -in "$RE_ZAP_CERT" -noout -subject_hash_old 2>/dev/null); then
            RE_CERT_FILE="$OUT_DIR/$RE_CERT_HASH.0"
            openssl x509 -inform "$FORM" -in "$RE_ZAP_CERT" -outform PEM -out "$RE_CERT_FILE" \
                || re_die "could not convert $RE_ZAP_CERT to PEM."
            return 0
        fi
    done
    re_die "$RE_ZAP_CERT is not a PEM or DER X.509 certificate."
}

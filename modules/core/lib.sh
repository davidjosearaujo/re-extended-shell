# shellcheck shell=bash
# RE Extended Shell - helpers shared by the commands of every module.
# Sourced by those scripts (always bash), never by your interactive shell.
# Each module's own helpers live in modules/<module>/lib.sh, which sources this.
# Must stay valid in bash 3.2 (macOS's /bin/bash) and work with both GNU
# (Linux) and BSD (macOS) userland tools.

RE_EXT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)

# The intercepting proxy on this machine (ZAP, Burp, mitmproxy, Charles, ...):
# its port and its root CA. Export either (e.g. in local/env.sh) to override.
# RE_ZAP_PORT, RE_ZAP_CERT and certs/zap_root_ca.cer are the names older
# versions used, still read so existing setups keep working.
RE_PROXY_PORT="${RE_PROXY_PORT:-${RE_ZAP_PORT:-9090}}"
if [ -z "${RE_PROXY_CERT:-${RE_ZAP_CERT:-}}" ]; then
    RE_PROXY_CERT="$RE_EXT_HOME/certs/proxy_ca.cer"
    [ -f "$RE_PROXY_CERT" ] || [ ! -f "$RE_EXT_HOME/certs/zap_root_ca.cer" ] \
        || RE_PROXY_CERT="$RE_EXT_HOME/certs/zap_root_ca.cer"
else
    RE_PROXY_CERT="${RE_PROXY_CERT:-$RE_ZAP_CERT}"
fi

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

# For option parsers: dies unless option $1 has a value after it. Without this,
# 'shift 2' on a last argument fails and the parsing loop never ends.
# Usage: -s|--serial) re_need_arg "$1" "$#"; SERIAL="$2"; shift 2 ;;
re_need_arg() {
    [ "$2" -ge 2 ] || re_die "$1 needs a value."
}

# --- What every command shares: help, errors, version ------------------------
# Every command follows the same conventions (see modules/README.md). Its option loop ends with:
#     -h|--help) re_help; exit 0 ;;
#     -*) re_unknown_option "$1" ;;
#     *)  re_unexpected_arg "$1" ;;      (or take it as an operand)
# and it defines usage(): the Usage line(s), a blank line, a description, then
# "Options:" (and optionally "Actions:", "Output:", "Examples:") sections.

RE_CMD=${0##*/}   # the running command's name, for messages

# Colours for terminal output (none when piped, or with NO_COLOR set)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RE_C_OK=$'\033[32m' RE_C_WARN=$'\033[33m' RE_C_FAIL=$'\033[31m'
    RE_C_BOLD=$'\033[1m' RE_C_DIM=$'\033[2m' RE_C_OFF=$'\033[0m'
else
    # shellcheck disable=SC2034  # used by the scripts that source this file
    RE_C_OK="" RE_C_WARN="" RE_C_FAIL="" RE_C_BOLD="" RE_C_DIM="" RE_C_OFF=""
fi

# "Warning: MESSAGE" on stderr
re_warn() {
    echo "Warning: $*" >&2
}

# Usage: -*) re_unknown_option "$1" ;;
re_unknown_option() {
    re_die "unknown option: $1 (see $RE_CMD --help)"
}

# An argument the command doesn't take. HINT replaces the pointer to --help.
# Usage: *) re_unexpected_arg "$1" ["name the device with -s SERIAL"] ;;
re_unexpected_arg() {
    re_die "unexpected argument: $1 (${2:-see $RE_CMD --help})"
}

# For a missing operand: the error, the Usage line(s) of usage(), then EXTRA
# (e.g. what could be picked), on stderr.
# Usage: [ -n "$APK" ] || re_usage_error "missing <file.apk>." ["EXTRA"]
re_usage_error() {
    {
        echo "Error: $1"
        usage | awk 'NR == 1 || /^       [^ ]/ { print; next } { exit }'
        [ -z "${2:-}" ] || printf '%s\n' "$2"
        echo "Run '$RE_CMD --help' for details."
    } >&2
    exit 1
}

# Version of this copy: its git tag if any (plus commits since), else the commit,
# with -dirty when edited; "unknown" outside a git checkout
re_version() {
    local V=""
    if [ -e "$RE_EXT_HOME/.git" ] && command -v git >/dev/null 2>&1; then
        V=$(git -C "$RE_EXT_HOME" describe --tags --always --dirty 2>/dev/null) || V=""
    fi
    echo "${V:-unknown}"
}

# Module names: core first, then the others alphabetically (as the shell loads them)
re_modules() {
    local D
    echo core
    for D in "$RE_EXT_HOME"/modules/*/; do
        D=${D%/}; D=${D##*/}
        [ "$D" = core ] || echo "$D"
    done
}

# Each module describes itself in modules/<module>/manifest:
#   about: one line saying what the module is for
#   setting: NAME | default | what it does | commands that use it
# Prints the module's "about" line.
re_module_about() {
    local L
    [ -f "$RE_EXT_HOME/modules/$1/manifest" ] || return 0
    while IFS= read -r L; do
        case "$L" in about:*) L=${L#about:}; echo "${L# }"; return 0 ;; esac
    done <"$RE_EXT_HOME/modules/$1/manifest"
}

# Prints MODULE|NAME|DEFAULT|DESCRIPTION|COMMANDS for every setting (of the
# given space-separated modules, default all; only those the command CMD uses,
# if given), fields trimmed. One awk for all the manifests.
# Usage: re_settings ["MODULE MODULE..."] [CMD]
re_settings() {
    local M FILES=()
    for M in ${1:-$(re_modules)}; do
        [ -f "$RE_EXT_HOME/modules/$M/manifest" ] && FILES+=("$RE_EXT_HOME/modules/$M/manifest")
    done
    [ "${#FILES[@]}" -gt 0 ] || return 0
    awk -F'|' -v cmd="${2:-}" '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        FNR == 1 { m = FILENAME; sub(/\/manifest$/, "", m); sub(/.*\//, "", m) }
        /^setting:/ {
            sub(/^setting:/, "")
            if (cmd != "") {
                n = split($4, a, " "); used = 0
                for (i = 1; i <= n; i++) if (a[i] == cmd) used = 1
                if (!used) next
            }
            print m "|" trim($1) "|" trim($2) "|" trim($3) "|" trim($4)
        }' "${FILES[@]}"
}

# Dies if PATH exists and force ($1) is empty. WHAT completes "use -f to ...".
# Usage: re_refuse_existing "$FORCE" PATH ["replace it"]
re_refuse_existing() {
    [ ! -e "$2" ] || [ -n "$1" ] || re_die "$2 already exists (use -f to ${3:-replace it})."
}

# Dies if PATTERN isn't an extended regular expression grep can parse (it
# exits 2 for those; 1 is just "no match"). OPTION names the flag it came in.
# Usage: re_check_regex OPTION PATTERN
re_check_regex() {
    printf '' | grep -E -- "$2" >/dev/null 2>&1
    [ "$?" != 2 ] || re_die "$1: not a valid extended regular expression: $2"
}

# Prints the command's help: its usage(), the settings it reads (from the
# manifests, with the value set in the environment, if any), and the footer
# every command shares.
re_help() {
    local LINES NAME DEFAULT DESC CMDS W=0 VALUE
    usage
    LINES=$(re_settings "" "$RE_CMD")
    if [ -n "$LINES" ]; then
        while IFS='|' read -r _ NAME _ _ _; do
            [ "${#NAME}" -le "$W" ] || W=${#NAME}
        done <<<"$LINES"
        echo
        echo "Settings (export them in local/env.sh):"
        while IFS='|' read -r _ NAME DEFAULT DESC CMDS; do
            VALUE=$(printenv "$NAME" 2>/dev/null)
            printf "  %-${W}s  %s (default: %s%s)\n" "$NAME" "$DESC" "$DEFAULT" "${VALUE:+; now: $VALUE}"
        done <<<"$LINES"
    fi
    echo
    echo "RE Extended Shell $(re_version). All commands: re-extended-shell --commands"
}

# --- Reports (bin-triage, apk-info, app-data) ---------------------------------
# A "== Title ==" section, then "  Label        value" rows and lists.
re_section() { printf '\n== %s ==\n' "$1"; }
# Usage: re_row LABEL VALUE
re_row() { printf '  %-12s %s\n' "$1" "$2"; }
# Prints stdin's non-empty lines indented, at most LIMIT of them (default 15)
# and then how many more there are, or "(none)".
# Usage: ... | re_list [LIMIT]
re_list() {
    awk -v limit="${1:-15}" '
        NF { n++; if (n <= limit) print "  " substr($0, 1, 160) }
        END { if (!n) print "  (none)"; else if (n > limit) print "  ... and " n - limit " more" }'
}

# --- Strings and secrets -------------------------------------------------------
# Words that name a secret, for grep -E (case-insensitive): the lines of text
# worth a look in a binary or an app's files
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_SECRET_WORDS='passw(or)?d|secret|token|api[_-]?key|credential|bearer|private[_-]?key'

# Runs stringx with the given arguments and prints each hit as "WHERE: STRING",
# WHERE being the file and, for a decoded hit, the decoding chain after it
# (app.bin->base64@193->gzip). Fails, printing nothing, if stringx isn't
# installed: callers fall back to binutils strings or grep.
# Usage: re_stringx [STRINGX ARGS...] FILE...
re_stringx() {
    command -v stringx >/dev/null 2>&1 || return 1
    stringx --color=never "$@" 2>/dev/null | awk '
        match($0, /:[0-9]+:[0-9]+:/) {
            where = substr($0, 1, RSTART - 1); sub(/^[ \t]+/, "", where)
            print where ": " substr($0, RSTART + RLENGTH)
        }'
}

# Shortens $HOME to ~ for display
re_tilde() { case "$1" in "$HOME"/*) echo "~${1#"$HOME"}" ;; *) echo "$1" ;; esac; }

# Prints the hex digest of FILE, with whichever tool this machine has: the GNU
# ones (md5sum, sha256sum, b2sum), the BSD/macOS ones (md5, shasum), else
# openssl; crc32 is zlib's (the one zip tools show, not cksum's), with python3.
# Fails, printing nothing, when none of them can do ALGO, so callers can skip
# that algorithm and say so.
# Usage: re_hash md5|sha1|sha224|sha256|sha384|sha512|sha3-256|sha3-512|blake2b|crc32 FILE
re_hash() {
    local ALGO="$1" FILE="$2" N="" OUT
    case "$ALGO" in sha1) N=1 ;; sha224) N=224 ;; sha256) N=256 ;; sha384) N=384 ;; sha512) N=512 ;; esac
    case "$ALGO" in
        crc32)
            command -v python3 >/dev/null 2>&1 || return 1
            python3 -I -c 'import sys, zlib
c = 0
with open(sys.argv[1], "rb") as f:
    for block in iter(lambda: f.read(1 << 20), b""):
        c = zlib.crc32(block, c)
print("%08x" % (c & 0xffffffff))' "$FILE" 2>/dev/null
            return ;;
        blake2b)
            if command -v b2sum >/dev/null 2>&1; then
                b2sum "$FILE" | awk '{ print $1 }'
                return
            fi
            ALGO=blake2b512 ;;   # openssl's name for it
        sha3-*|blake2*) ;;       # openssl only
        *)
            if command -v "${ALGO}sum" >/dev/null 2>&1; then
                "${ALGO}sum" "$FILE" | awk '{ print $1 }'
                return
            elif [ "$ALGO" = md5 ] && command -v md5 >/dev/null 2>&1; then
                md5 -q "$FILE"
                return
            elif [ -n "$N" ] && command -v shasum >/dev/null 2>&1; then
                shasum -a "$N" "$FILE" | awk '{ print $1 }'
                return
            fi ;;
    esac
    command -v openssl >/dev/null 2>&1 || return 1
    # "SHA3-256(file)= abc..." or "abc... *file", depending on the version
    OUT=$(openssl dgst "-$ALGO" "$FILE" 2>/dev/null | awk '{ print $NF }')
    case "$OUT" in ""|*[!0-9a-fA-F]*) return 1 ;; esac
    echo "$OUT"
}

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

# Prints PEM or DER, the format of the X.509 certificate FILE; fails if it
# isn't one (or openssl is missing).
re_cert_form() {
    local F
    for F in PEM DER; do
        if openssl x509 -inform "$F" -in "$1" -noout 2>/dev/null; then echo "$F"; return 0; fi
    done
    return 1
}

# Warns when nothing listens on PORT (default: $RE_PROXY_PORT) on this machine.
# Usage: re_warn_proxy_down [PORT]
re_warn_proxy_down() {
    re_port_listening "${1:-$RE_PROXY_PORT}" \
        || re_warn "nothing listens on port ${1:-$RE_PROXY_PORT}, is your proxy running?"
}

# Exits with export instructions unless $RE_PROXY_CERT exists
re_require_proxy_cert() {
    [ -f "$RE_PROXY_CERT" ] && return 0
    cat >&2 <<EOF
Error: your proxy's root CA certificate is not at: $RE_PROXY_CERT
Export it from your intercepting proxy (PEM or DER), e.g.:
  ZAP:        Tools > Options > Network > Server Certificates > Save
  Burp:       Proxy > Proxy settings > Import / export CA certificate
  mitmproxy:  ~/.mitmproxy/mitmproxy-ca-cert.pem
then save it to that path, or point RE_PROXY_CERT at it (e.g. in local/env.sh).
EOF
    exit 1
}

# shellcheck shell=bash
# RE Extended Shell - helpers for the binary module's commands (bin/).
# Sourced by those scripts (always bash), never by your interactive shell.
# Same portability rules as core/lib.sh: bash 3.2, GNU and BSD tools.

# shellcheck source=../core/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/../core/lib.sh"

# shellcheck disable=SC2034  # used by the scripts that source this file
RE_BINARY_DIR="$RE_EXT_HOME/modules/binary"   # libexec/ holds the helper programs

# Prints FILE's printable strings (at least MINLEN characters, default 6) read
# with stringx when it's installed (ASCII and UTF-16), else binutils strings
# (ASCII only, the reason bin-triage and crypto-libs say "install stringx").
# A caller that needs one or the other to exist checks before calling.
# Usage: re_strings_raw FILE [MINLEN]
re_strings_raw() {
    local FILE="$1" MINLEN="${2:-6}"
    if command -v stringx >/dev/null 2>&1; then
        stringx -q -e all -l "$MINLEN:" "$FILE" 2>/dev/null
    else
        strings -a -n "$MINLEN" "$FILE" 2>/dev/null
    fi
}

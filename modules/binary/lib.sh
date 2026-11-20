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

# Dies unless one of the symbol readers re_syms uses is installed
re_require_symtools() {
    command -v nm >/dev/null 2>&1 || command -v readelf >/dev/null 2>&1 || command -v objdump >/dev/null 2>&1 \
        || re_die "none of nm, readelf or objdump is installed (binutils on Linux, the Xcode command line tools on macOS)."
}

# Demangles the C++ names on stdin, or passes them through without c++filt
re_demangle() { if command -v c++filt >/dev/null 2>&1; then c++filt; else cat; fi; }

# Prints the symbol names FILE exports, imports, or exports as functions (the
# ones a Frida hook can attach to: no data), one per line, sorted, as stored
# (C++ names still mangled, which is what a lookup by name needs). Tries the
# GNU nm flags, then the BSD ones, then readelf and objdump, so it works with
# either userland and whatever is installed; prints nothing when none of them
# can read the file.
# Usage: re_syms FILE exports|imports|functions
re_syms() {
    local F="$1" KIND="$2" OUT=""
    if command -v nm >/dev/null 2>&1; then
        if [ "$KIND" = imports ]; then
            OUT=$(nm -D --undefined-only "$F" 2>/dev/null)
            [ -n "$OUT" ] || OUT=$(nm -gu "$F" 2>/dev/null)
            [ -n "$OUT" ] || OUT=$(nm -g --undefined-only "$F" 2>/dev/null)
            OUT=$(printf '%s\n' "$OUT" | awk 'NF >= 2 && $(NF-1) == "U" { print $NF }')
        else
            OUT=$(nm -D --defined-only "$F" 2>/dev/null)
            [ -n "$OUT" ] || OUT=$(nm -gU "$F" 2>/dev/null)
            [ -n "$OUT" ] || OUT=$(nm -g --defined-only "$F" 2>/dev/null)
            # Code and data, or code only: 'A' is a version node (ZLIB_1.2.0),
            # which nothing can call or hook
            OUT=$(printf '%s\n' "$OUT" | awk -v kind="$KIND" '
                NF >= 3 && $(NF-1) ~ (kind == "functions" ? "^[TWi]$" : "^[TWDBRVGSi]$") { print $NF }')
        fi
    fi
    if [ -z "$OUT" ] && command -v readelf >/dev/null 2>&1; then
        OUT=$(readelf --wide --dyn-syms "$F" 2>/dev/null | awk -v kind="$KIND" '
            NF >= 8 && ($5 == "GLOBAL" || $5 == "WEAK") {
                if (kind == "imports") { if ($7 == "UND") print $8; next }
                if ($7 == "UND") next
                if (kind == "exports" || $4 == "FUNC" || $4 == "IFUNC") print $8
            }')
    fi
    if [ -z "$OUT" ] && [ "$KIND" != imports ] && command -v objdump >/dev/null 2>&1; then
        # "0000000000001139 g    DF .text  0000000000000020  Base  name": F is a function
        OUT=$(objdump -T "$F" 2>/dev/null | awk -v kind="$KIND" '
            NF > 6 && $0 !~ /\*UND\*/ && (kind == "exports" || $0 ~ / D?F /) { print $NF }')
    fi
    # "0000 T name@@GLIBC_2.17" -> "name"
    printf '%s\n' "$OUT" | awk 'NF { sub(/@.*/, "", $NF); if ($NF != "") print $NF }' | LC_ALL=C sort -u
}

# Prints the name a Frida hook finds FILE's module by: its ELF SONAME, else the
# file name.
re_so_module() {
    local M=""
    ! command -v readelf >/dev/null 2>&1 || M=$(readelf -d "$1" 2>/dev/null | awk -F'[][]' '/SONAME/ { print $2; exit }')
    echo "${M:-$(basename -- "$1")}"
}

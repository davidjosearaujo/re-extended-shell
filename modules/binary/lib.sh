# shellcheck shell=bash
# RE Extended Shell - helpers for the binary module's commands (bin/).
# Sourced by those scripts (always bash), never by your interactive shell.
# Same portability rules as core/lib.sh: bash 3.2, GNU and BSD tools.

# shellcheck source=../core/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/../core/lib.sh"

# Prints the hex digest of FILE: md5, sha1 or sha256. Uses whichever of the
# GNU (md5sum, sha256sum), BSD/macOS (md5, shasum) or openssl tools exists.
# Usage: re_hash md5|sha1|sha256 FILE
re_hash() {
    local ALGO="$1" FILE="$2" N
    case "$ALGO" in sha1) N=1 ;; sha256) N=256 ;; esac
    if command -v "${ALGO}sum" >/dev/null 2>&1; then
        "${ALGO}sum" "$FILE" | awk '{ print $1 }'
    elif [ "$ALGO" = md5 ] && command -v md5 >/dev/null 2>&1; then
        md5 -q "$FILE"
    elif [ -n "${N:-}" ] && command -v shasum >/dev/null 2>&1; then
        shasum -a "$N" "$FILE" | awk '{ print $1 }'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst "-$ALGO" -r "$FILE" | awk '{ print $1 }'
    else
        return 1
    fi
}

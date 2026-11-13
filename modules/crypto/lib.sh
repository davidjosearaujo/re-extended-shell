# shellcheck shell=bash
# RE Extended Shell - helpers for the crypto module's commands (bin/).
# Sourced by those scripts (always bash), never by your interactive shell.
# Same portability rules as core/lib.sh: bash 3.2, GNU and BSD tools.

# shellcheck source=../core/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/../core/lib.sh"

# Every digest re_hash knows, in the order the reports print them, with the
# label each one gets. file-hash and doctor.sh read this.
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_HASH_ALGOS="md5:MD5 sha1:SHA-1 sha224:SHA-224 sha256:SHA-256 sha384:SHA-384 sha512:SHA-512 sha3-256:SHA3-256 sha3-512:SHA3-512 blake2b:BLAKE2b crc32:CRC-32"

# --- Dates: GNU and BSD date(1) take different flags, so these hide that -----

# Prints an epoch second as a local date, "2026-11-12 18:00:00 CET".
# Usage: re_epoch_date 1794505068
re_epoch_date() {
    case "$1" in ""|*[!0-9]*) echo "not a number: $1"; return 1 ;; esac
    date -r "$1" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null \
        || date -d "@$1" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null \
        || echo "epoch $1"
}

# Prints the epoch second of a date as openssl writes them ("Nov 12 17:00:00
# 2026 GMT"); fails, printing nothing, when neither date(1) can parse it.
# Usage: re_date_epoch "Nov 12 17:00:00 2026 GMT"
re_date_epoch() {
    local D
    D=$(printf '%s' "$1" | tr -s ' ')
    date -j -u -f '%b %d %T %Y %Z' "$D" +%s 2>/dev/null && return 0
    date -u -d "$D" +%s 2>/dev/null && return 0
    return 1
}

# Prints a signed number of seconds as "in 3 days" or "2 hours ago", rounded to
# the largest unit that still reads naturally (so 1799 seconds is 30 minutes,
# not 29, and 2701 is an hour rather than 45 minutes).
# Usage: re_relative_time -7200
re_relative_time() {
    awk -v d="$1" 'BEGIN {
        ago = (d < 0); if (ago) d = -d
        if      (d < 45)             { n = d;                      unit = "second" }
        else if (d < 45 * 60)        { n = int(d / 60 + 0.5);      unit = "minute" }
        else if (d < 22 * 3600)      { n = int(d / 3600 + 0.5);    unit = "hour" }
        else if (d < 320 * 86400)    { n = int(d / 86400 + 0.5);   unit = "day" }
        else                         { n = int(d / 31536000 + 0.5); unit = "year" }
        printf "%s%d %s%s%s", (ago ? "" : "in "), n, unit, (n == 1 ? "" : "s"), (ago ? " ago" : "")
    }'
}

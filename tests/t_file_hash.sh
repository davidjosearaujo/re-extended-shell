# shellcheck shell=bash
# file-hash: every digest of a file, --check against an expected one, and the
# duplicates in a tree. The digests of "abc" are the published test vectors.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset

printf abc >"$T_DIR/abc"
printf xyz >"$T_DIR/xyz"

MD5=900150983cd24fb0d6963f7d28e17f72
SHA1=a9993e364706816aba3e25717850c26c9cd0d89d
SHA256=ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
SHA3=3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532

run file-hash "$T_DIR/abc"
expect_rc 0 "runs on a file"
expect_out "$MD5" "MD5 of 'abc'"
expect_out "$SHA1" "SHA-1 of 'abc'"
expect_out "$SHA256" "SHA-256 of 'abc'"
expect_out "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f" \
    "SHA-512 of 'abc'"
expect_out "3 bytes" "prints the size"
expect_no_out "VirusTotal" "no VirusTotal URL unless asked"

run file-hash --vt "$T_DIR/abc"
expect_out "https://www.virustotal.com/gui/file/$SHA256" "--vt prints the URL of its SHA-256"

# The digests openssl does and coreutils doesn't, when this machine has it
if command -v openssl >/dev/null 2>&1; then
    run file-hash --algo sha3-256 "$T_DIR/abc"
    expect_out "$SHA3" "SHA3-256 of 'abc'"
else
    skip "SHA3-256 of 'abc'" "openssl not installed"
fi
# The CRC-32 is zlib's, so a value from a zip listing checks out
if command -v python3 >/dev/null 2>&1; then
    run file-hash --check 0x352441C2 "$T_DIR/abc"
    expect_rc 0 "--check takes a zip tool's CRC-32, 0x prefix included"
    expect_out "has that CRC-32 digest" "...and names CRC-32"
else
    skip "--check takes a zip tool's CRC-32, 0x prefix included" "python3 not installed"
    skip "...and names CRC-32" "python3 not installed"
fi

run file-hash --algo sha256,md5,SHA256 "$T_DIR/abc"
expect_out "$SHA256" "--algo keeps the algorithms asked for"
expect_no_out "$SHA1" "...and leaves out the others"
expect_eq "$(grep -c "$SHA256" <<<"$OUT")" 1 "...printing one named twice only once"

run file-hash --algo nope "$T_DIR/abc"
expect_rc 1 "--algo rejects an unknown algorithm"
expect_out "unknown algorithm: nope" "...and names it"

# --check: the algorithm doesn't have to be known, and the format is forgiving
run file-hash --check "$SHA256" "$T_DIR/abc"
expect_rc 0 "--check with the right SHA-256 succeeds"
expect_out "has that SHA-256 digest" "...and says which algorithm matched"

run file-hash --check "90:01:50:98:3C:D2:4F:B0:D6:96:3F:7D:28:E1:7F:72" "$T_DIR/abc"
expect_rc 0 "--check takes an uppercase, colon-separated MD5"
expect_out "has that MD5 digest" "...and names MD5"

run file-hash --check "$SHA256" "$T_DIR/xyz"
expect_rc 1 "--check on another file exits non-zero"
expect_out "No match" "...and says so"

run file-hash --check zz "$T_DIR/abc"
expect_rc 1 "--check rejects a value that isn't hex"

run file-hash --check "$SHA256" "$T_DIR/abc" "$T_DIR/xyz"
expect_rc 1 "--check refuses more than one file"

# A tree: one line per file, and the duplicates in it
mkdir -p "$T_DIR/tree/a" "$T_DIR/tree/b"
printf abc >"$T_DIR/tree/a/one"
printf abc >"$T_DIR/tree/b/two"
printf xyz >"$T_DIR/tree/b/three"

run file-hash "$T_DIR/tree"
expect_rc 1 "a directory without -r is an error"
expect_out "use -r to walk it" "...pointing at -r"

run file-hash --vt -r "$T_DIR/tree"
expect_rc 1 "--vt with -r is an error"
expect_out "goes with the report" "...saying where --vt applies"

run file-hash -r "$T_DIR/tree"
expect_rc 0 "-r walks a directory"
expect_out "$SHA256  $T_DIR/tree/a/one" "...printing SHA-256 and the path per file"
expect_out "$T_DIR/tree/b/three" "...for every file in it"

run file-hash --algo md5 -r "$T_DIR/tree"
expect_out "$MD5  $T_DIR/tree/a/one" "-r uses the algorithm --algo names"

run file-hash --dups -r "$T_DIR/tree"
expect_rc 0 "--dups groups identical files"
expect_out "2 files, SHA-256 $SHA256" "...naming the digest they share"
expect_out "1 group of identical files, 2 of the 3 files" "...and counting them"
expect_no_out "tree/b/three" "...leaving out the file that is unique"

run file-hash --dups -r "$T_DIR/xyz"
expect_out "No duplicates among 1 file." "--dups on one file says there are none"

run file-hash "$T_DIR/nope"
expect_rc 1 "a missing file is an error"
expect_out "file not found" "...saying so"

run file-hash
expect_rc 1 "no argument is a usage error"
expect_out "missing <file>" "...naming what's missing"

done_testing

# shellcheck shell=bash
# crypto-find: the crypto constants built into a file, in both byte orders,
# base64 alphabets (standard and shuffled), archive members, and --min.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset

if ! command -v python3 >/dev/null 2>&1; then
    skip "crypto-find" "python3 not installed"
    done_testing
    exit 0
fi

# A blob with real constants: AES forward S-box, SHA-256 K little-endian,
# ChaCha's sigma, a shuffled custom base64 alphabet, and the TEA delta (low)
python3 - "$T_DIR/blob.bin" <<'PY'
import struct, sys
b = b"HEADER\x00\x00"
b += bytes.fromhex("637c777bf26b6fc53001672bfed7ab76ca82c97dfa5947f0"
                   "add4a2af9ca472c0b7fd9326363ff7cc34a5e5f171d83115"
                   "04c723c31896059a071280e2eb27b275")          # AES S-box
b += b"\x00" * 8
K = [0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,
     0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3]
b += b"".join(struct.pack("<I", w) for w in K)                  # SHA-256 K, LE
b += b"\x00" * 8 + b"expand 32-byte k" + b"\x00" * 8
b += struct.pack("<I", 0x9e3779b9)                              # TEA delta (low)
b += b"\x00" * 8
b += b"BADCFEHGJILKNMPORQTSVUXWZYbadcfehgjilknmporqtsvuxwzy0123456789+/"  # shuffled b64
open(sys.argv[1], "wb").write(b)
PY

run crypto-find "$T_DIR/blob.bin"
expect_rc 0 "finds constants in a blob"
expect_out "AES" "finds AES by its S-box"
expect_out "forward S-box" "...naming which table"
expect_out "SHA-256" "finds SHA-256 by its K table, stored little-endian"
expect_out "ChaCha/Salsa20" "finds ChaCha by its sigma string"
expect_out "custom alphabet (shuffled)" "spots a shuffled custom base64 alphabet"
expect_out "TEA/XTEA/XXTEA" "finds the TEA delta"
expect_out "fingerprint" "ends with the caveat about fingerprints"

# --min-confidence drops the low-confidence TEA delta
run crypto-find --min-confidence medium "$T_DIR/blob.bin"
expect_rc 0 "runs with --min-confidence medium"
expect_out "AES" "...keeps the high-confidence hits"
expect_no_out "TEA/XTEA" "...and drops the low-confidence delta"

run crypto-find --min-confidence bogus "$T_DIR/blob.bin"
expect_rc 1 "--min-confidence rejects a bad value"
expect_out "takes low, medium or high" "...saying what it takes"

# The standard alphabet is labelled as such, not as custom
printf 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' >"$T_DIR/std.bin"
run crypto-find "$T_DIR/std.bin"
expect_out "standard alphabet" "names the standard base64 alphabet"
expect_no_out "shuffled" "...and doesn't call it custom"

# A file with nothing in it
head -c 256 /dev/zero >"$T_DIR/zero.bin"
run crypto-find "$T_DIR/zero.bin"
expect_rc 1 "nothing found exits non-zero"
expect_out "No crypto constants found" "...and says so"

# Inside an archive: members are scanned, the container isn't double-counted
if command -v zip >/dev/null 2>&1; then
    mkdir -p "$T_DIR/pack/lib"
    cp "$T_DIR/blob.bin" "$T_DIR/pack/lib/libx.so"
    ( cd "$T_DIR/pack" && zip -qr "$T_DIR/pack.zip" . )
    run crypto-find "$T_DIR/pack.zip"
    expect_rc 0 "reads an archive"
    expect_out "pack.zip!lib/libx.so" "...naming the member a hit is in"
    expect_out "AES" "...and finding its constants"
    expect_eq "$(grep -c 'forward S-box' <<<"$OUT")" 1 "...without double-counting a stored member"
else
    skip "reads an archive" "zip not installed"
fi

run crypto-find "$T_DIR/nope"
expect_rc 1 "a missing file is an error"
expect_out "file not found" "...saying so"

run crypto-find
expect_rc 1 "no argument is a usage error"
expect_out "missing <file" "...naming what's missing"

done_testing

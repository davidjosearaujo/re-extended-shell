# shellcheck shell=bash
# proto-extract, on the descriptors in tests/fixtures/proto, put where the
# protobuf runtimes leave them (built with Python's standard library only)
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
if ! command -v python3 >/dev/null 2>&1; then
    skip "proto-extract" "python3 not installed"
    done_testing
    exit 0
fi
FX="$TESTS/fixtures/proto"
cd "$T_DIR" || exit 1

# A native library (C++, Rust, Go v2): the raw bytes between other data; a Go
# binary from before protobuf-go v2: gzipped; a dex file (Java): a string in
# Modified UTF-8; an APK holding the dex and the library; a Python module
python3 -I - "$FX" <<'PY'
import gzip, os, struct, sys, zipfile
fx = sys.argv[1]
orders = open(fx + "/orders.desc", "rb").read()
desc = open(fx + "/descriptor.desc", "rb").read()
open("native.so", "wb").write(os.urandom(2000) + orders + os.urandom(300) + desc + b"\0" * 9)
g = gzip.compress(orders, compresslevel=9, mtime=0)
open("go.bin", "wb").write(os.urandom(64) + g[:8] + b"\x02\xff" + g[10:] + os.urandom(64))
def mutf8(bs):
    return b"".join(b"\xc0\x80" if b == 0 else bytes([b]) if b < 0x80 else bytes([0xC0 | b >> 6, 0x80 | b & 0x3F]) for b in bs)
strings = [b"Lcom/acme/Foo;", orders]
data, offs = b"", []
for s in strings:
    offs.append(0x70 + 4 * len(strings) + len(data))
    n = len(s); data += bytes([n & 0x7F | 0x80, n >> 7]) + mutf8(s) + b"\0"
hdr = bytearray(b"dex\n035\0" + bytes(0x68))
struct.pack_into("<II", hdr, 0x38, len(strings), 0x70)
dex = bytes(hdr) + b"".join(struct.pack("<I", o) for o in offs) + data
open("classes.dex", "wb").write(dex)
with zipfile.ZipFile("app.apk", "w") as z:
    z.writestr("classes.dex", dex)
    z.writestr("lib/arm64-v8a/libnative.so", open("native.so", "rb").read())
open("orders_pb2.py", "w").write("DESCRIPTOR = _pool.AddSerializedFile(%r)\n" % orders)
PY

# The recovered file, without its two header lines (they name the source)
body() { sed 1,2d "$1"; }

for INPUT in native.so go.bin classes.dex orders_pb2.py; do
    run proto-extract -o "out-$INPUT" "$INPUT"
    expect_rc 0 "$INPUT: finds the descriptor"
    if [ -f "out-$INPUT/acme/api/v1/orders.proto" ] && [ "$(body "out-$INPUT/acme/api/v1/orders.proto")" = "$(cat "$FX/orders.proto.expected")" ]; then
        pass "...and writes acme/api/v1/orders.proto as expected"
    else
        fail "...and writes acme/api/v1/orders.proto as expected" "$(diff <(body "out-$INPUT/acme/api/v1/orders.proto" 2>&1) "$FX/orders.proto.expected")"
    fi
done

run proto-extract app.apk
expect_rc 0 "an APK: runs"
expect_out "3 messages, 0 enums, 1 service, from app.apk!classes.dex" "...names the member it came from"
expect_out "1 standard google/protobuf one skipped (--all keeps them)" "...skips the standard types"
[ -f app-protos/acme/api/v1/orders.proto ] && [ ! -e app-protos/google ] \
    && pass "...into ./<name>-protos/ by default" || fail "...into ./<name>-protos/ by default" "$(find app-protos)"
expect_out "Decode a message with: protoc --decode=" "...and says how to use them"

run proto-extract --all -o all native.so
expect_out "2 .proto files recovered" "--all keeps the standard types"
if [ "$(body all/google/protobuf/descriptor.proto)" = "$(cat "$FX/descriptor.proto.expected")" ]; then
    pass "...descriptor.proto (proto2: defaults, extension ranges) as expected"
else
    fail "...descriptor.proto (proto2: defaults, extension ranges) as expected" "$(diff <(body all/google/protobuf/descriptor.proto) "$FX/descriptor.proto.expected" | head -20)"
fi

# A cut-off descriptor: written, but marked as incomplete
python3 -I -c "import sys; d = open(sys.argv[1], 'rb').read(); open('cut.bin', 'wb').write(d[:-40])" "$FX/orders.desc"
run proto-extract -o cut cut.bin
expect_out "incomplete" "a cut-off descriptor is reported as incomplete"
grep -q '^// INCOMPLETE' cut/acme/api/v1/orders.proto 2>/dev/null \
    && pass "...and the file says so" || fail "...and the file says so"

# Nothing to find, refusals
printf 'nothing here, not even foo.proto\n' >plain.txt
run proto-extract plain.txt
expect_rc 1 "nothing found fails"
expect_out "No descriptors found" "...and says what that may mean"
[ ! -e plain-protos ] && pass "...leaving no empty folder behind" || fail "...leaving no empty folder behind"
run proto-extract app.apk
expect_rc 1 "refuses to replace an earlier output"
expect_out "already exists (use -f" "...and says to use -f"
run proto-extract -f app.apk
expect_rc 0 "...unless given -f"
run proto-extract missing.bin
expect_out "file not found: missing.bin" "a missing input"

done_testing

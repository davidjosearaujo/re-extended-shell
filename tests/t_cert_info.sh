# shellcheck shell=bash
# cert-info: what a certificate says, in PEM and DER, the values the Android
# work needs (SPKI pin, system store file name), and PEM output.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset

if ! command -v openssl >/dev/null 2>&1; then
    skip "cert-info" "openssl not installed"
    done_testing
    exit 0
fi

# A CA like a proxy's, a leaf without basicConstraints, and an expired one
openssl req -x509 -newkey rsa:2048 -nodes -days 400 -subj "/CN=Test Proxy CA/O=RE Test" \
    -addext "basicConstraints=critical,CA:TRUE" -addext "subjectAltName=DNS:proxy.test" \
    -keyout "$T_DIR/ca.key" -out "$T_DIR/ca.pem" >/dev/null 2>&1
openssl x509 -in "$T_DIR/ca.pem" -outform DER -out "$T_DIR/ca.der" 2>/dev/null
# -not_before/-not_after is OpenSSL 3.x; older ones can't backdate a certificate
openssl req -x509 -newkey rsa:2048 -nodes -subj "/CN=Gone" \
    -not_before 20200101000000Z -not_after 20200102000000Z \
    -keyout "$T_DIR/old.key" -out "$T_DIR/old.pem" >/dev/null 2>&1
printf 'not a certificate\n' >"$T_DIR/junk.txt"

# The pin and the store file name, computed the way the rest of the toolkit does
PIN=$(openssl x509 -in "$T_DIR/ca.pem" -pubkey -noout | openssl pkey -pubin -outform der \
    | openssl dgst -sha256 -binary | openssl base64 -A)
HASH=$(openssl x509 -in "$T_DIR/ca.pem" -noout -subject_hash_old)

run cert-info "$T_DIR/ca.pem"
expect_rc 0 "reads a PEM certificate"
expect_out "CN=Test Proxy CA" "prints the subject"
expect_out "(self-signed)" "says a self-signed certificate is one"
expect_out "DNS:proxy.test" "lists the names it covers"
expect_out "valid, expires in" "says how long it has left"
expect_out "2048 bit" "prints the key size"
expect_out "sha256/$PIN" "prints the SPKI pin an app would pin"
expect_out "$HASH.0" "prints the Android system store file name"
expect_out "(PEM)" "names the format it read"

run cert-info "$T_DIR/ca.der"
expect_rc 0 "reads a DER certificate"
expect_out "CN=Test Proxy CA" "...the same subject"
expect_out "sha256/$PIN" "...and the same pin"
expect_out "(DER)" "naming DER this time"

if [ -s "$T_DIR/old.pem" ]; then
    run cert-info "$T_DIR/old.pem"
    expect_rc 0 "reads an expired certificate"
    expect_out "expired" "...and says it has expired"
else
    skip "reads an expired certificate" "this openssl can't backdate one"
    skip "...and says it has expired" "this openssl can't backdate one"
fi

run cert-info "$T_DIR/junk.txt"
expect_rc 1 "a file that isn't a certificate is an error"
expect_out "not an X.509 certificate" "...saying what it isn't"

# No argument: the proxy CA, with the export instructions when it isn't there
fake_cert
run cert-info
expect_rc 0 "with no argument it reads RE_PROXY_CERT"
expect_out "CN=Test Proxy CA" "...the proxy CA's subject"
expect_out "your proxy's CA (RE_PROXY_CERT)" "...saying where it came from"

export RE_PROXY_CERT="$T_DIR/missing.cer"
run cert-info
expect_rc 1 "with no proxy CA at all it fails"
expect_out "Export it from your intercepting proxy" "...with the usual instructions"
export RE_PROXY_CERT="$T_DIR/proxy.cer"

# PEM output: a DER file turned into one, and nothing overwritten by accident
run cert-info --pem "$T_DIR/ca.der"
expect_rc 0 "--pem converts DER to PEM"
expect_out "BEGIN CERTIFICATE" "...printing a PEM block"

run cert-info --pem -o "$T_DIR/out.pem" "$T_DIR/ca.der"
expect_rc 0 "--pem -o writes a file"
expect_out "Certificate written: $T_DIR/out.pem" "...saying where"
if [ -s "$T_DIR/out.pem" ] && openssl x509 -in "$T_DIR/out.pem" -noout 2>/dev/null; then
    pass "...and the file is a usable certificate"
else
    fail "...and the file is a usable certificate"
fi

run cert-info --pem -o "$T_DIR/out.pem" "$T_DIR/ca.der"
expect_rc 1 "--pem -o won't replace an existing file"
expect_out "already exists" "...saying so"

run cert-info --pem -o "$T_DIR/out.pem" -f "$T_DIR/ca.der"
expect_rc 0 "...unless -f is given"

run cert-info -o "$T_DIR/other.pem" "$T_DIR/ca.pem"
expect_rc 1 "-o without --pem is an error"

run cert-info "$T_DIR/ca.pem" "$T_DIR/ca.der"
expect_rc 1 "two certificates at once is an error"

run cert-info "$T_DIR/nope.pem"
expect_rc 1 "a missing file is an error"
expect_out "file not found" "...saying so"

run cert-info "localhost:notaport"
expect_rc 1 "a host with a bad port is an error"
expect_out "not a port number" "...saying so"

# A TLS server of its own on localhost, so the host form is covered without a
# network: it must report the same certificate as the file above
# A port unlikely to be taken, so this never reads someone else's server
PORT=$((20000 + ($$ % 10000)))
openssl s_server -quiet -key "$T_DIR/ca.key" -cert "$T_DIR/ca.pem" -accept "$PORT" >/dev/null 2>&1 &
SRV=$!
N=0
while [ "$N" -lt 50 ] && ! (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; do
    N=$((N + 1))
    sleep 0.1
done
if [ "$N" -lt 50 ]; then
    run cert-info "localhost:$PORT"
    expect_rc 0 "reads the chain a TLS server sends"
    expect_out "CN=Test Proxy CA" "...the certificate it presents"
    expect_out "sha256/$PIN" "...with the same pin as the file it was made from"
    expect_out "== Connection ==" "...and a section for the connection"
    expect_out "TLSv1" "...naming the TLS version"
    expect_out "self-signed certificate" "...and that the chain didn't verify"
else
    skip "reads the chain a TLS server sends" "openssl s_server didn't come up on port $PORT"
fi
kill "$SRV" 2>/dev/null
wait "$SRV" 2>/dev/null

done_testing

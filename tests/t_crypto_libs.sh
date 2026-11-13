# shellcheck shell=bash
# crypto-libs: names the crypto/TLS libraries in a file's strings, with their
# version, the Java providers in a dex's class names, and APK members.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset

# A file whose strings carry several library banners and package names
{
    printf 'random junk here\n'
    printf 'OpenSSL 1.0.2k-fips  26 Jan 2017\n'
    printf 'mbed TLS 2.28.0\n'
    printf 'Lorg/bouncycastle/jce/provider/BouncyCastleProvider;\n'
    printf 'org.conscrypt.OpenSSLProvider\n'
    printf 'net/sqlcipher/database/SQLiteDatabase\n'
} >"$T_DIR/banners.bin"

run crypto-libs "$T_DIR/banners.bin"
expect_rc 0 "finds libraries in a file's strings"
expect_out "OpenSSL" "names OpenSSL"
expect_out "1.0.2k" "...with its version"
expect_out "mbedTLS" "names mbedTLS"
expect_out "2.28.0" "...with its version"
expect_out "Bouncy Castle" "names Bouncy Castle from its package"
expect_out "Conscrypt" "names Conscrypt"
expect_out "SQLCipher" "names SQLCipher"
expect_out "not proof the code is used" "ends with the caveat"

# A file with no crypto library in it
printf 'nothing to see here, just plain text and numbers 12345\n' >"$T_DIR/plain.bin"
run crypto-libs "$T_DIR/plain.bin"
expect_rc 1 "a file with no library exits non-zero"
expect_out "No known crypto or TLS library" "...and says so"

# An APK: the .so and .dex members are scanned, named by member
if command -v zip >/dev/null 2>&1; then
    mkdir -p "$T_DIR/app/lib/arm64-v8a"
    printf 'built with OpenSSL 1.1.1w  11 Sep 2023 inside\n' >"$T_DIR/app/lib/arm64-v8a/libssl.so"
    printf 'Lorg/bouncycastle/crypto/Y;\n' >"$T_DIR/app/classes.dex"
    printf 'resource, not scanned\n' >"$T_DIR/app/res.txt"
    ( cd "$T_DIR/app" && zip -qr "$T_DIR/app.apk" . )
    run crypto-libs "$T_DIR/app.apk"
    expect_rc 0 "reads an APK"
    expect_out "app.apk!lib/arm64-v8a/libssl.so" "names the native member"
    expect_out "1.1.1w" "...with the library version in it"
    expect_out "app.apk!classes.dex" "names the dex member"
    expect_out "Bouncy Castle" "...and the provider in it"
    expect_no_out "res.txt" "doesn't scan non-code members"
else
    skip "reads an APK" "zip not installed"
fi

run crypto-libs "$T_DIR/nope"
expect_rc 1 "a missing file is an error"
expect_out "file not found" "...saying so"

run crypto-libs
expect_rc 1 "no argument is a usage error"
expect_out "missing <file" "...naming what's missing"

done_testing

# shellcheck shell=bash
# so-exports: the symbols a library exports, its JNI entry points first, the
# module name a Frida hook needs, and the filters.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset

printf 'not an object file\n' >"$T_DIR/text.txt"

run so-exports "$T_DIR/nope.so"
expect_rc 1 "a missing file is an error"
expect_out "file not found" "...saying so"

run so-exports
expect_rc 1 "no argument is a usage error"
expect_out "missing <file>" "...naming what's missing"

run so-exports -l x "$T_DIR/text.txt"
expect_rc 1 "-l rejects a value that isn't a number"
run so-exports -l 0 "$T_DIR/text.txt"
expect_rc 1 "-l rejects 0"
expect_out "--all shows everything" "...pointing at --all"
run so-exports -g '(' "$T_DIR/text.txt"
expect_rc 1 "-g rejects a pattern grep can't parse"
expect_out "not a valid extended regular expression" "...saying so"

run so-exports "$T_DIR/text.txt"
expect_rc 0 "runs on a file that has no symbols"
expect_out "Nothing readable here" "...and says there is nothing to read"

# A library of this machine's own, built with symbols worth finding. Without a
# compiler the checks fall back to a system library, and without one of those
# (or nm) they are skipped.
CC=""
for C in cc gcc clang; do command -v "$C" >/dev/null 2>&1 && CC=$C && break; done
LIB=""
if [ -n "$CC" ]; then
    cat >"$T_DIR/lib.c" <<'C'
int JNI_OnLoad(void *vm, void *reserved) { return 0x00010006; }
int Java_com_example_Crypto_encrypt(void *env, void *clazz) { return 42; }
int helper_sign_payload(int n) { return n + 1; }
static int not_exported(void) { return 7; }
int uses_static(void) { return not_exported(); }
C
    if "$CC" -shared -fPIC -Wl,-soname,libtest.so -o "$T_DIR/libtest.so" "$T_DIR/lib.c" >/dev/null 2>&1; then
        LIB="$T_DIR/libtest.so"
    fi
fi

if [ -n "$LIB" ]; then
    run so-exports "$LIB"
    expect_rc 0 "runs on a shared library"
    expect_out "== JNI entry points ==" "has a JNI section"
    expect_out "JNI_OnLoad" "...listing JNI_OnLoad"
    expect_out "Java_com_example_Crypto_encrypt" "...and the Java_ entry point"
    expect_out "== Other exports ==" "lists the other exports apart"
    expect_out "helper_sign_payload" "...with the ones that aren't JNI"
    expect_eq "$(grep -c '^  JNI_OnLoad$' <<<"$OUT")" 1 "...without repeating the JNI ones"
    expect_no_out "not_exported" "leaves out what isn't exported"
    expect_out "Module       libtest.so" "prints the SONAME as the module name"
    expect_out "Interceptor.attach(Module.getExportByName('libtest.so', 'JNI_OnLoad')" \
        "ends with a Frida hook for a JNI entry point"

    run so-exports -g 'sign|crypt' "$LIB"
    expect_out "Other exports matching 'sign|crypt'" "-g says what it filtered on"
    expect_out "JNI entry points matching 'sign|crypt'" "...on the JNI list too"
    expect_out "helper_sign_payload" "...keeping the symbols that match"
    expect_no_out "uses_static" "...and dropping the ones that don't"

    # Two JNI exports and two others, so each list hides one at -l 1
    run so-exports -l 1 "$LIB"
    expect_out "and 1 more" "-l limits each list"
    run so-exports --all "$LIB"
    expect_no_out " more" "--all shows every symbol"

    run so-exports --imports "$LIB"
    expect_out "== Imports ==" "--imports lists what it needs"

    # Two files in one run
    run so-exports -l 1 "$LIB" "$LIB"
    expect_rc 0 "takes several files"
elif command -v nm >/dev/null 2>&1 && [ -r /lib/x86_64-linux-gnu/libz.so.1 ]; then
    run so-exports /lib/x86_64-linux-gnu/libz.so.1
    expect_rc 0 "runs on a shared library"
    expect_out "== Exports ==" "lists its exports"
    expect_out "inflate" "...including a function it has"
    expect_no_out "  ZLIB_1.2" "leaves out the version nodes, which nothing can call"
    expect_out "Interceptor.attach" "ends with a Frida hook"
else
    skip "runs on a shared library" "no compiler and no system library to read"
fi

done_testing

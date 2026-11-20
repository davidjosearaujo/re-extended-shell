# shellcheck shell=bash
# frida-hook: a Frida script for a library's JNI entry points or chosen
# exports, with Java names for the JNI ones.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset
cd "$T_DIR" || exit 1

run frida-hook
expect_rc 1 "no argument is a usage error"
expect_out "missing <file.so>" "...naming what's missing"
run frida-hook "$T_DIR/nope.so"
expect_rc 1 "a missing file is an error"
printf 'not an object file\n' >"$T_DIR/text.txt"
run frida-hook --args x "$T_DIR/text.txt"
expect_rc 1 "--args rejects a value that isn't a number"
run frida-hook -g '(' "$T_DIR/text.txt"
expect_rc 1 "-g rejects a pattern grep can't parse"
run frida-hook "$T_DIR/text.txt"
expect_rc 1 "a file without symbols is an error"
expect_out "exports no functions" "...saying so"

CC=""
for C in cc gcc clang; do command -v "$C" >/dev/null 2>&1 && CC=$C && break; done
LIB="" PLAIN=""
if [ -n "$CC" ] && command -v nm >/dev/null 2>&1; then
    cat >"$T_DIR/lib.c" <<'C'
int JNI_OnLoad(void *vm, void *reserved) { return 0x00010006; }
int Java_com_example_Crypto_encrypt(void *env, void *clazz) { return 42; }
int Java_com_ex_1ample_Crypto_dec__Ljava_lang_String_2(void *env, void *clazz) { return 1; }
int helper_sign_payload(int n) { return n + 1; }
int exported_table = 5;
C
    printf 'int plain_sign(int n) { return n; }\nint plain_other(int n) { return n; }\n' >"$T_DIR/plain.c"
    "$CC" -shared -fPIC -Wl,-soname,libtest.so -o "$T_DIR/libtest.so" "$T_DIR/lib.c" >/dev/null 2>&1 && LIB="$T_DIR/libtest.so"
    "$CC" -shared -fPIC -o "$T_DIR/libplain.so" "$T_DIR/plain.c" >/dev/null 2>&1 && PLAIN="$T_DIR/libplain.so"
fi

if [ -n "$LIB" ] && [ -n "$PLAIN" ]; then
    run frida-hook "$LIB"
    expect_rc 0 "writes a script for a library"
    expect_out "Hooked       3 of 4 exported functions" "...hooking its JNI entry points, data left out"
    expect_out "com.example.Crypto.encrypt" "...with the Java name of a native method"
    expect_out "com.ex_ample.Crypto.dec" "...decoding _1 and dropping an overload's signature"
    expect_out "Frida script: $T_DIR/libtest-hook.js" "...into ./<library>-hook.js"
    SCRIPT=$(cat "$T_DIR/libtest-hook.js" 2>/dev/null)
    grep -qF "['Java_com_example_Crypto_encrypt', 'com.example.Crypto.encrypt', true]," <<<"$SCRIPT" \
        && pass "...hooking the JNI symbol, marked as JNI" || fail "...hooking the JNI symbol, marked as JNI" "$SCRIPT"
    grep -qF "['JNI_OnLoad', 'JNI_OnLoad', false]," <<<"$SCRIPT" \
        && pass "...and JNI_OnLoad, which isn't a native method" || fail "...and JNI_OnLoad, which isn't a native method" "$SCRIPT"
    grep -qF "const MODULES = ['libtest.so'];" <<<"$SCRIPT" \
        && pass "...finding the module by its name" || fail "...finding the module by its name" "$SCRIPT"
    if command -v node >/dev/null 2>&1; then
        node --check "$T_DIR/libtest-hook.js" >/dev/null 2>&1 \
            && pass "...as valid JavaScript" || fail "...as valid JavaScript" "$(node --check "$T_DIR/libtest-hook.js" 2>&1)"
    else
        skip "...as valid JavaScript" "node isn't installed"
    fi

    run frida-hook "$LIB"
    expect_rc 1 "an existing script isn't replaced"
    expect_out "use -f" "...without -f"
    run frida-hook -f --args 2 --backtrace "$LIB"
    expect_rc 0 "-f replaces it"
    grep -qF "const BACKTRACE = true;" "$T_DIR/libtest-hook.js" && grep -qF "const ARGS = 2;" "$T_DIR/libtest-hook.js" \
        && pass "--args and --backtrace go into the script" || fail "--args and --backtrace go into the script"

    run frida-hook -o - -g 'sign|table' "$LIB"
    expect_rc 0 "-o - writes to stdout"
    expect_out "['helper_sign_payload', 'helper_sign_payload', false]," "-g picks functions by name"
    expect_no_out "exported_table" "...never data"
    expect_no_out "Java_com_example" "...instead of the JNI ones"

    run frida-hook -o - "$LIB" helper_sign_payload com.example.Crypto.encrypt
    expect_out "'helper_sign_payload'" "functions can be named"
    expect_out "'Java_com_example_Crypto_encrypt'" "...by symbol or by Java name"
    run frida-hook -o - "$LIB" exported_table
    expect_rc 1 "a name that isn't an exported function is an error"

    run frida-hook -o - "$PLAIN"
    expect_rc 1 "a library without JNI entry points needs -g or names"
    expect_out "pick the functions to hook with -g" "...and says so"
    run frida-hook -o - -g plain_sign "$PLAIN"
    expect_rc 0 "...which then works"
else
    skip "writes a script for a library" "no C compiler or nm to build one with"
fi

done_testing

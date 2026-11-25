# shellcheck shell=bash
# app-memdump: finds Frida's Python, starts frida-server, dumps the app's
# memory through libexec/memdump.py and searches the strings in it. Frida's
# bindings are fake (tests/fake/py/frida.py), in a venv the fake frida CLI runs on.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
cd "$T_DIR" || exit 1

# Stock Frida and a fixed on-device name (see t_frida.sh for the rest)
export RE_FRIDA_SOURCE=frida RE_FRIDA_NAME=frida-server

# frida-server comes from the cache, never downloaded
FRIDA_DIR="$HOME/.local/share/re-extended-shell/frida"
mkdir -p "$FRIDA_DIR"
echo fake-binary >"$FRIDA_DIR/frida-server-16.0.0-android-x86_64"

setup() {
    fake_reset; fake_emulator emulator-5554 TestAvd_A
    echo 4321 >"$FAKE_STATE/pid.com.example.app"
}

setup
run app-memdump
expect_rc 1 "no package is a usage error"
expect_out "missing <PACKAGE>" "...naming what's missing"
run app-memdump -g '(' com.example.app
expect_rc 1 "-g rejects a pattern grep can't parse"
run app-memdump --process 'x;rm' com.example.app
expect_rc 1 "--process rejects a name with shell characters"

# The fake frida CLI is a bash script, so its Python is python3, which has no
# bindings (unless this machine installed them system-wide)
if ! python3 -I -c 'import frida' >/dev/null 2>&1; then
    run app-memdump com.example.app
    expect_rc 1 "without Frida's Python bindings it fails"
    expect_out "pipx install frida-tools" "...saying how to get them"
fi

# A venv with the fake bindings, and a frida CLI that runs on it, the way pipx
# installs frida-tools
VENV="$T_DIR/venv"
if python3 -m venv --without-pip "$VENV" >/dev/null 2>&1; then
    SITE=$("$VENV/bin/python" -I -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')
    cp "$TESTS/fake/py/frida.py" "$SITE/"
    mkdir -p "$T_DIR/fridabin"
    {
        echo "#!$VENV/bin/python"
        echo 'import os, sys'
        printf '%s\n' 'open(os.environ["FAKE_STATE"] + "/log", "a").write("frida " + " ".join(sys.argv[1:]) + "\n")'
        echo 'if sys.argv[1:] == ["--version"]: print("16.0.0")'
    } >"$T_DIR/fridabin/frida"
    chmod +x "$T_DIR/fridabin/frida"
    WITH=(env "PATH=$T_DIR/fridabin:$PATH")

    setup; rm -f "$FAKE_STATE/pid.com.example.app"
    run "${WITH[@]}" app-memdump com.example.app
    expect_rc 1 "an app that isn't running is an error"
    expect_out "com.example.app isn't running on emulator-5554" "...saying so"

    setup
    run "${WITH[@]}" app-memdump -n TestAvd_A com.example.app
    expect_rc 0 "dumps a running app"
    expect_log "frida-server -D" "...starting frida-server first"
    expect_log "frida-py attach emulator-5554 4321" "...attaching to the app's pid on that device"
    expect_log "frida-py ranges all=False" "...leaving out system files"
    D="$T_DIR/com.example.app-memdump"
    expect_eq "$(wc -c <"$D/ranges/0x1000.bin" | tr -d ' ')" 8192 "...a file per range, at its full size"
    expect_eq "$(tail -c 4096 "$D/ranges/0x1000.bin" | tr -d '\0' | wc -c | tr -d ' ')" 0 "...the unreadable page as zeros"
    grep -q "^0x1000	8192	rw-	$" "$D/ranges.tsv" && pass "...listed in ranges.tsv" || fail "...listed in ranges.tsv" "$(cat "$D/ranges.tsv")"
    expect_out "Unreadable   4 KiB" "...and says how much couldn't be read"
    grep -q "utf16-s3cr3t-value" "$D/strings.txt" && pass "strings.txt has the UTF-16 strings too" \
        || fail "strings.txt has the UTF-16 strings too" "$(cat "$D/strings.txt")"
    expect_out "password=hunter2" "lists a password"
    expect_out "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ" "...a JWT"
    expect_out "Bearer abcdefghijklmnop" "...and a bearer token"
    [ ! -e "$D.part" ] && pass "...leaving no partial dump behind" || fail "...leaving no partial dump behind"

    run "${WITH[@]}" app-memdump com.example.app
    expect_rc 1 "an existing dump isn't replaced"
    expect_out "use -f" "...without -f"

    setup
    run "${WITH[@]}" app-memdump -f --all -g 'S3CR3T' com.example.app
    expect_rc 0 "-f replaces it"
    expect_log "frida-py ranges all=True" "--all dumps system files too"
    [ -f "$D/ranges/0x7000.bin" ] && pass "...into their own range file" || fail "...into their own range file"
    expect_out "Matching 'S3CR3T'" "-g lists the strings that match"
    expect_out "utf16-s3cr3t-value" "...case-insensitively"

    setup; echo 999 >"$FAKE_STATE/pid.com.example.app"
    run "${WITH[@]}" app-memdump -o "$T_DIR/gone" com.example.app
    expect_rc 1 "a process that went away is an error"
    expect_out "Frida: unable to find process" "...with Frida's reason"
    [ ! -e "$T_DIR/gone" ] && [ ! -e "$T_DIR/gone.part" ] && pass "...leaving nothing behind" \
        || fail "...leaving nothing behind"
else
    skip "dumps a running app" "python3 can't create a venv"
fi

done_testing

# shellcheck shell=bash
# Helpers for the tests, sourced by every tests/t_*.sh. Output is TAP-like:
# "ok - description" or "not ok - description" plus indented details.

TESTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO=${TESTS%/tests}

T_DIR=$(mktemp -d)
trap 'rm -rf "$T_DIR"' EXIT

# Nothing from the real environment leaks in: own HOME, own settings, and the
# fakes ahead of any real adb/emulator/frida/scrcpy on PATH
export HOME="$T_DIR/home" TMPDIR="$T_DIR/tmp"
mkdir -p "$HOME" "$TMPDIR"
unset ANDROID_HOME ANDROID_SDK_ROOT ANDROID_NDK_HOME JAVA_HOME RE_ZAP_PORT RE_ZAP_CERT \
      RE_ZAP_SNAPSHOT JADX JADX_GUI APKEDITOR_JAR RE_FRIDA_UNPIN_REF RE_FRIDA_UNPIN_SCRIPTS \
      RE_CONTAINER_ENGINE RE_ANDROID_CONTAINER_IMAGE
export PATH="$TESTS/fake:$REPO/modules/core/bin:$REPO/modules/android/bin:$REPO/modules/binary/bin:$PATH"

# Starts every scenario from a clean slate: no devices, no AVDs, empty log.
fake_reset() {
    export FAKE_STATE="$T_DIR/state" ANDROID_AVD_HOME="$T_DIR/avd"
    rm -rf "$FAKE_STATE" "$ANDROID_AVD_HOME"
    mkdir -p "$FAKE_STATE" "$ANDROID_AVD_HOME"
    : >"$FAKE_STATE/devices"
    : >"$FAKE_STATE/log"
}

# fake_emulator SERIAL AVD_NAME [SNAPSHOT...]: a running emulator whose AVD has these snapshots
fake_emulator() {
    local SERIAL="$1" AVD="$2"
    shift 2
    echo "$SERIAL|$AVD|device" >>"$FAKE_STATE/devices"
    fake_avd "$AVD" "$@"
}

# fake_avd NAME [SNAPSHOT...]: an AVD on disk (not necessarily running)
fake_avd() {
    local AVD="$1" SNAP
    shift
    echo "path=$ANDROID_AVD_HOME/$AVD.avd" >"$ANDROID_AVD_HOME/$AVD.ini"
    mkdir -p "$ANDROID_AVD_HOME/$AVD.avd/snapshots"
    for SNAP in "$@"; do mkdir -p "$ANDROID_AVD_HOME/$AVD.avd/snapshots/$SNAP"; done
}

# fake_device SERIAL [STATE]: a connected physical device
fake_device() { echo "$1||${2:-device}" >>"$FAKE_STATE/devices"; }

# A throwaway self-signed CA, for the commands that need $RE_ZAP_CERT
fake_cert() {
    command -v openssl >/dev/null 2>&1 || return 1
    export RE_ZAP_CERT="$T_DIR/zap.cer"
    [ -f "$RE_ZAP_CERT" ] || openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=Test ZAP CA" \
        -keyout "$T_DIR/zap.key" -out "$RE_ZAP_CERT" >/dev/null 2>&1
}

# run COMMAND [ARG...]: sets OUT (stdout and stderr) and RC. A command that
# hangs is killed after 30s and reported as RC=124.
run() {
    local PID N=0
    "$@" >"$T_DIR/out" 2>&1 </dev/null &
    PID=$!
    while kill -0 "$PID" 2>/dev/null; do
        N=$((N + 1))
        if [ "$N" -gt 300 ]; then
            kill -9 "$PID" 2>/dev/null
            wait "$PID" 2>/dev/null
            RC=124
            OUT=$(cat "$T_DIR/out")
            return 0
        fi
        sleep 0.1
    done
    wait "$PID"
    RC=$?
    OUT=$(cat "$T_DIR/out")
}

pass() { echo "ok - $1"; }
fail() {
    echo "not ok - $1"
    shift
    local L
    for L in "$@"; do echo "    $L"; done
}

# expect_rc EXPECTED DESCRIPTION: the last run() exited with this code
expect_rc() {
    if [ "$RC" = "$1" ]; then pass "$2"; else fail "$2" "exit code $RC, wanted $1" "output: $OUT"; fi
}
# _expect_text yes|no TEXT HAYSTACK DESCRIPTION LABEL: whether HAYSTACK contains TEXT
_expect_text() {
    local FOUND=no
    grep -qF -- "$2" <<<"$3" && FOUND=yes
    if [ "$FOUND" = "$1" ]; then
        pass "$4"
    elif [ "$1" = yes ]; then
        fail "$4" "missing: $2" "$5: $3"
    else
        fail "$4" "unexpected: $2" "$5: $3"
    fi
}
# expect_out / expect_no_out TEXT DESCRIPTION: the last run() printed TEXT (a fixed string), or didn't
expect_out()    { _expect_text yes "$1" "$OUT" "$2" output; }
expect_no_out() { _expect_text no "$1" "$OUT" "$2" output; }
# expect_log / expect_no_log TEXT DESCRIPTION: the fakes were called with TEXT in a line, or weren't
expect_log()    { _expect_text yes "$1" "$(cat "$FAKE_STATE/log")" "$2" log; }
expect_no_log() { _expect_text no "$1" "$(cat "$FAKE_STATE/log")" "$2" log; }
# expect_eq ACTUAL EXPECTED DESCRIPTION
expect_eq() {
    if [ "$1" = "$2" ]; then pass "$3"; else fail "$3" "got:    $1" "wanted: $2"; fi
}
# skip DESCRIPTION REASON
skip() { echo "ok - $1 # SKIP $2"; }

done_testing() { echo "# done"; }

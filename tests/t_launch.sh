# shellcheck shell=bash
# launch-emulator, release-device and frida-server against the fakes.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

if ! fake_cert; then
    skip "launch-emulator and friends" "openssl not installed"
    done_testing; exit 0
fi

# --- a physical device -------------------------------------------------------
fake_reset; fake_device PHONE123
run launch-emulator -d
expect_rc 0 "launch-emulator -d on a fake phone"
expect_log "scrcpy -s PHONE123" "opens scrcpy"
expect_no_log "shell id -u" "by default doesn't look for root"
expect_no_log "frida-server" "...pushes no frida-server"
expect_no_log "inject_ca.sh" "by default injects no CA"
expect_no_log "http_proxy 127" "...sets no proxy"
expect_no_log "reverse tcp" "...and opens no tunnel"

fake_reset; fake_device PHONE123
run launch-emulator -d --proxy 8080 --ca "$RE_PROXY_CERT"
expect_rc 0 "launch-emulator -d --proxy --ca"
expect_log "-s PHONE123 reverse tcp:8080 tcp:8080" "tunnels the given port"
expect_log "settings put global http_proxy 127.0.0.1:8080" "sets the proxy to it"
expect_log "inject_ca.sh" "pushes the CA injection script"
# Another tool's tunnel, which release-device must leave alone
adb -s PHONE123 reverse tcp:9090 tcp:9090
run release-device -s PHONE123
expect_rc 0 "release-device -s"
expect_log "settings put global http_proxy :0" "clears the proxy"
expect_log "reverse --remove tcp:8080" "removes the proxy's tunnel"
expect_no_log "reverse --remove tcp:9090" "...but not another one"
expect_out "injected CA stays trusted" "says the CA stays until a reboot"
: >"$FAKE_STATE/log"
run release-device -s PHONE123
expect_no_log "reverse --remove" "with no proxy set, removes no tunnel"
expect_no_out "injected CA" "...and mentions no CA"

fake_reset; fake_device PHONE123
adb -s PHONE123 shell settings put global http_proxy 127.0.0.1:9090
run launch-emulator -d
expect_out "still has a global HTTP proxy (127.0.0.1:9090)" "warns about a proxy left from before"

run launch-emulator -d --proxy 8080
expect_rc 1 "--proxy without --ca is refused"
run launch-emulator -d --ca "$RE_PROXY_CERT"
expect_rc 1 "--ca without --proxy is refused"
run launch-emulator -d --proxy http --ca "$RE_PROXY_CERT"
expect_rc 1 "a non-numeric port is refused"
run launch-emulator -d --proxy 70000 --ca "$RE_PROXY_CERT"
expect_rc 1 "an out-of-range port is refused"
run launch-emulator -d --proxy 8080 --ca "$T_DIR/nope.cer"
expect_rc 1 "a missing CA file is refused"
expect_out "certificate not found" "...saying so"
printf 'not a cert' >"$T_DIR/bad.cer"
run launch-emulator -d --proxy 8080 --ca "$T_DIR/bad.cer"
expect_rc 1 "a file that isn't a certificate is refused"

fake_reset; fake_device PHONE123; fake_device PHONE456
run launch-emulator -d
expect_rc 1 "several phones and no -s is an error"
run launch-emulator -s PHONE456
expect_rc 0 "-s picks the phone and implies -d"
expect_log "scrcpy -s PHONE456" "...on that phone"
run launch-emulator -s PHONE456 TestAvd_A
expect_rc 1 "-s with an AVD name is refused"
run launch-emulator -s PHONE456 --snapshot
expect_rc 1 "--snapshot on a phone is refused"
run launch-emulator -s PHONE456 --read-only
expect_rc 1 "--read-only on a phone is refused"

fake_reset
run launch-emulator -d
expect_rc 1 "no device connected is an error"

# frida-server comes from the cache, never downloaded
FRIDA_DIR="$HOME/.local/share/re-extended-shell/frida"
mkdir -p "$FRIDA_DIR"
echo fake-binary >"$FRIDA_DIR/frida-server-16.0.0-android-x86_64"

# --- an emulator ---------------------------------------------------------------
# By default, as it is: no wipe, no snapshot loaded or saved, nothing else
fake_reset; fake_avd TestAvd_A re-ready
run launch-emulator TestAvd_A
expect_rc 0 "launch-emulator boots a fake AVD"
expect_out "Starting AVD: TestAvd_A (as it is)" "by default, as it is"
expect_log "emulator -avd TestAvd_A -port 5554 -no-snapshot-save -netdelay" "...without saving its state"
expect_no_log "-wipe-data" "...without wiping it"
expect_no_log "-snapshot re-ready" "...ignoring the snapshot"
expect_no_log "snapshot save" "...saving none"
expect_no_log "shell id -u" "...without root"
expect_no_log "frida-server" "...or frida-server"
expect_no_log "inject_ca.sh" "...or a CA"
expect_no_log "settings put global http_proxy" "...or a proxy"
fake_reset; fake_avd TestAvd_A
run launch-emulator --read-only TestAvd_A
expect_log "-no-snapshot-save -read-only" "--read-only boots read-only"

# Already running: that emulator is used
fake_reset; fake_emulator emulator-5556 TestAvd_A
run launch-emulator --push-frida-server TestAvd_A
expect_rc 0 "a running AVD..."
expect_out "already running as emulator-5556, using it" "...is used as it is"
expect_no_log "emulator -avd" "...without starting another"
expect_log "push $FRIDA_DIR/frida-server-16.0.0" "...and set up as asked"
run launch-emulator --snapshot TestAvd_A
expect_rc 1 "--snapshot on a running AVD is refused"
: >"$FAKE_STATE/log"
run launch-emulator --read-only TestAvd_A
expect_log "emulator -avd TestAvd_A" "--read-only starts a second one"

# --start-frida-server: one frida-server call (push and start), unless a
# snapshot is saved in between
fake_reset; fake_avd TestAvd_A
run launch-emulator --start-frida-server TestAvd_A
expect_log "frida-server -D" "--start-frida-server starts it"
expect_eq "$(grep -c 'getprop ro.product.cpu.abi' "$FAKE_STATE/log")" 1 "...in one frida-server call"
fake_reset; fake_avd TestAvd_A
run launch-emulator --snapshot --start-frida-server TestAvd_A
LOG=$(cat "$FAKE_STATE/log")
SAVE_AT=$(grep -n "snapshot save" <<<"$LOG" | cut -d: -f1)
START_AT=$(grep -n "frida-server -D" <<<"$LOG" | head -n 1 | cut -d: -f1)
[ -n "$SAVE_AT" ] && [ -n "$START_AT" ] && [ "$SAVE_AT" -lt "$START_AT" ] \
    && pass "...and with --snapshot, starts it after the save" || fail "...and with --snapshot, starts it after the save" "$LOG"

# Leftovers from an earlier --proxy
fake_reset; fake_emulator emulator-5554 TestAvd_A
adb -s emulator-5554 shell settings put global http_proxy 10.0.2.2:9090
run launch-emulator TestAvd_A
expect_out "still has a global HTTP proxy (10.0.2.2:9090)" "warns about a proxy left from before"

# --snapshot: the first boot saves it, the next ones use it
fake_reset; fake_avd TestAvd_A
run launch-emulator --snapshot --push-frida-server TestAvd_A
expect_rc 0 "--snapshot with no snapshot yet"
expect_out "no 're-ready' snapshot yet: as it is, will save it" "...boots the AVD as it is"
expect_no_log "-wipe-data" "...without wiping it"
expect_log "emulator -avd TestAvd_A -port 5554 -no-snapshot-save -netdelay" "...or loading a snapshot"
expect_log "emu avd snapshot save re-ready" "...and saves the snapshot"
LOG=$(cat "$FAKE_STATE/log")
SAVE_AT=$(grep -n "snapshot save" <<<"$LOG" | cut -d: -f1)
PUSH_AT=$(grep -n "push $FRIDA_DIR/frida-server-" <<<"$LOG" | head -n 1 | cut -d: -f1)
[ -n "$SAVE_AT" ] && [ -n "$PUSH_AT" ] && [ "$PUSH_AT" -lt "$SAVE_AT" ] \
    && pass "...with frida-server pushed first, so it's in the snapshot" || fail "...with frida-server pushed first, so it's in the snapshot" "$LOG"
fake_reset; fake_avd TestAvd_A
run launch-emulator --snapshot --proxy 8080 --ca "$RE_PROXY_CERT" TestAvd_A
expect_rc 0 "--snapshot --proxy --ca on a fake AVD"
expect_log "settings put global http_proxy 10.0.2.2:8080" "emulators proxy to 10.0.2.2"
expect_no_log "reverse tcp" "...with no adb reverse"
LOG=$(cat "$FAKE_STATE/log")
SAVE_AT=$(grep -n "snapshot save" <<<"$LOG" | cut -d: -f1)
INJECT_AT=$(grep -n "inject_ca.sh" <<<"$LOG" | head -n 1 | cut -d: -f1)
[ -n "$SAVE_AT" ] && [ -n "$INJECT_AT" ] && [ "$SAVE_AT" -lt "$INJECT_AT" ] \
    && pass "...after saving the snapshot, which stays clean" || fail "...after saving the snapshot, which stays clean" "$LOG"
fake_reset; fake_avd TestAvd_A zap-ready
run launch-emulator --snapshot TestAvd_A
expect_out "old 'zap-ready' snapshot" "points out an old zap-ready snapshot"
fake_reset; fake_avd TestAvd_A re-ready
run launch-emulator --snapshot TestAvd_A
expect_out "from snapshot 're-ready'" "later boots use the snapshot"
expect_log "-snapshot re-ready -no-snapshot-save" "...loading it"
expect_no_log "snapshot save" "...and do not save again"
fake_reset; fake_avd TestAvd_A re-ready
run launch-emulator --snapshot --read-only TestAvd_A
expect_log "-snapshot re-ready -no-snapshot-save -read-only" "--snapshot --read-only loads it read-only"
fake_reset; fake_avd TestAvd_A
run launch-emulator --snapshot --read-only TestAvd_A
expect_rc 1 "--read-only can't create the snapshot"
fake_reset; fake_avd TestAvd_A re-ready
run launch-emulator --clean TestAvd_A
expect_out "wiped boot, snapshot 're-ready' rebuilt after" "--clean ignores the snapshot"
expect_log "-wipe-data" "...wipes"
expect_log "emu avd snapshot save re-ready" "...and rebuilds it"

# --snapshot NAME: another snapshot, created the same way
fake_reset; fake_avd TestAvd_A re-ready
run launch-emulator --snapshot banking TestAvd_A
expect_rc 0 "--snapshot NAME before the AVD"
expect_out "no 'banking' snapshot yet" "...creates that snapshot"
expect_log "emu avd snapshot save banking" "...under that name"
expect_no_log "-wipe-data" "...without wiping"
expect_out "launch-emulator --snapshot banking TestAvd_A" "...and says how to boot it"
fake_reset; fake_avd TestAvd_A banking
run launch-emulator TestAvd_A --snapshot banking
expect_log "-snapshot banking -no-snapshot-save" "--snapshot NAME after the AVD boots from it"
fake_reset; fake_avd TestAvd_A banking
run launch-emulator --snapshot=banking TestAvd_A
expect_log "-snapshot banking -no-snapshot-save" "--snapshot=NAME too"
fake_reset; fake_avd TestAvd_A re-ready
run launch-emulator --snapshot TestAvd_A --read-only
expect_log "-snapshot re-ready" "a word after --snapshot with no AVD after it is the AVD"
run launch-emulator --snapshot ../x TestAvd_A
expect_rc 1 "a snapshot name with a slash is refused"
fake_reset; fake_avd TestAvd_A re-ready
run launch-emulator --clean old TestAvd_A
expect_rc 1 "--clean takes no name (it goes with --snapshot NAME)"
run launch-emulator --clean --snapshot old TestAvd_A
expect_log "emu avd snapshot save old" "--clean --snapshot NAME rebuilds that one"

run launch-emulator --clean --read-only TestAvd_A
expect_rc 1 "--clean with --read-only is refused"
run launch-emulator NoSuchAvd
expect_rc 1 "an unknown AVD is an error"
NOFRIDA=""
while IFS= read -r D; do [ -x "$D/frida" ] || NOFRIDA="$NOFRIDA${NOFRIDA:+:}$D"; done < <(tr ':' '\n' <<<"$PATH")
fake_reset; fake_avd TestAvd_A
PATH="$NOFRIDA" run launch-emulator --push-frida-server TestAvd_A
expect_rc 1 "--push-frida-server without Frida here is refused"
expect_no_log "emulator -avd" "...before booting anything"

# --- frida-server -----------------------------------------------------------
fake_reset; fake_emulator emulator-5554 TestAvd_A
run frida-server --push-only
expect_rc 0 "frida-server --push-only with the build cached"
expect_log "push $FRIDA_DIR/frida-server-16.0.0-android-x86_64" "pushes the cached build"

UNPIN="$FRIDA_DIR/unpinning/main"
mkdir -p "$UNPIN/android"
cat >"$UNPIN/config.js" <<'JS'
const CERT_PEM = `[!! Put your CA certificate here !!]`;
const PROXY_HOST = '';
const PROXY_PORT = 0;
JS
for F in native-tls-hook.js android/android-proxy-override.js android/android-system-certificate-injection.js android/android-certificate-unpinning.js android/android-certificate-unpinning-fallback.js; do
    : >"$UNPIN/$F"
done
run frida-server --ssl-unpinning com.example.app
expect_rc 0 "frida-server --ssl-unpinning on an emulator"
expect_log "frida -D emulator-5554 -f com.example.app" "spawns the app under frida"
expect_log "const PROXY_HOST = '10.0.2.2';" "the emulator proxy host is filled in"
expect_log "const PROXY_PORT = 9090;" "...and the port"
fake_reset; fake_device PHONE123
run frida-server --ssl-unpinning com.example.app
expect_log "const PROXY_HOST = '127.0.0.1';" "a phone gets localhost..."
expect_log "reverse tcp:9090 tcp:9090" "...and the adb reverse tunnel"

done_testing

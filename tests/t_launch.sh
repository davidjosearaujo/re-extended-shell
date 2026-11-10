# shellcheck shell=bash
# launch-emulator, release-device and frida-server against the fakes.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

if ! fake_cert; then
    skip "launch-emulator and friends" "openssl not installed"
    done_testing; exit 0
fi

# --- a physical device -------------------------------------------------------
fake_reset; fake_device PHONE123
run launch-emulator -d --no-frida
expect_rc 0 "launch-emulator -d on a fake phone"
expect_log "-s PHONE123 reverse tcp:9090 tcp:9090" "tunnels the ZAP port"
expect_log "settings put global http_proxy 127.0.0.1:9090" "sets the proxy"
expect_log "scrcpy -s PHONE123" "opens scrcpy"
expect_log "inject_ca.sh" "pushes the CA injection script"
run release-device -s PHONE123
expect_rc 0 "release-device -s"
expect_log "settings put global http_proxy :0" "clears the proxy"
expect_log "reverse --remove tcp:9090" "removes the tunnel"

fake_reset; fake_device PHONE123; fake_device PHONE456
run launch-emulator -d --no-frida
expect_rc 1 "several phones and no -s is an error"
run launch-emulator -s PHONE456 --no-frida
expect_rc 0 "-s picks the phone and implies -d"
expect_log "scrcpy -s PHONE456" "...on that phone"
run launch-emulator -s PHONE456 TestAvd_A
expect_rc 1 "-s with an AVD name is refused"

fake_reset
run launch-emulator -d --no-frida
expect_rc 1 "no device connected is an error"

# --- an emulator: first boot saves the snapshot, the next one uses it ---------
fake_reset; fake_avd TestAvd_A
run launch-emulator --no-frida TestAvd_A
expect_rc 0 "launch-emulator boots a fake AVD"
expect_out "no 'zap-ready' snapshot, wiped boot, will create it" "first boot is a wiped boot"
expect_log "emu avd snapshot save zap-ready" "...and saves the snapshot"
expect_log "settings put global http_proxy 10.0.2.2:9090" "emulators proxy to 10.0.2.2"
expect_no_log "reverse tcp" "...with no adb reverse"
fake_reset; fake_avd TestAvd_A zap-ready
run launch-emulator --no-frida TestAvd_A
expect_out "from snapshot 'zap-ready'" "later boots use the snapshot"
expect_no_log "snapshot save" "...and do not save again"
fake_reset; fake_avd TestAvd_A zap-ready
run launch-emulator --clean --no-frida TestAvd_A
expect_out "wiped boot, snapshot ignored and rebuilt" "--clean ignores the snapshot"
expect_log "emu avd snapshot save zap-ready" "...and rebuilds it"
run launch-emulator --no-frida NoSuchAvd
expect_rc 1 "an unknown AVD is an error"
run launch-emulator --no-frida --start-frida-server TestAvd_A
expect_rc 1 "--no-frida with --start-frida-server is refused"

# --- frida-server -----------------------------------------------------------
fake_reset; fake_emulator emulator-5554 TestAvd_A
FRIDA_DIR="$HOME/.local/share/re-extended-shell/frida"
mkdir -p "$FRIDA_DIR"
echo fake-binary >"$FRIDA_DIR/frida-server-16.0.0-android-x86_64"
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

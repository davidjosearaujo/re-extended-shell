# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

fake_reset; fake_emulator emulator-5554 TestAvd_A
run device-proxy
expect_rc 1 "no action prints usage and fails"
run device-proxy on
expect_rc 0 "on, emulator"
expect_log "settings put global http_proxy 10.0.2.2:9090" "emulator proxies to 10.0.2.2"
expect_no_log "reverse" "...without an adb reverse tunnel"
run device-proxy status
expect_out "proxy 10.0.2.2:9090" "status shows it"
run device-proxy off
expect_log "settings put global http_proxy :0" "off clears it"
run device-proxy status
expect_out "no proxy set" "status after off"

fake_reset; fake_device PHONE123
RE_PROXY_PORT=8081 run device-proxy on
expect_rc 0 "on, physical device"
expect_log "-s PHONE123 reverse tcp:8081 tcp:8081" "sets up the adb reverse tunnel"
expect_log "settings put global http_proxy 127.0.0.1:8081" "proxies to localhost"
expect_out "before unplugging" "warns about unplugging"
RE_PROXY_PORT=8081 run device-proxy status
expect_out "proxy 127.0.0.1:8081" "status shows the phone's proxy"
expect_no_out "no adb reverse tunnel" "...and no tunnel warning while it is in place"
mv "$FAKE_STATE/reverse.PHONE123" "$T_DIR/reverse.saved"
RE_PROXY_PORT=8081 run device-proxy status
expect_out "no adb reverse tunnel" "status warns when the tunnel is gone"
mv "$T_DIR/reverse.saved" "$FAKE_STATE/reverse.PHONE123"
RE_PROXY_PORT=8081 run device-proxy -s PHONE123 off
expect_log "reverse --remove tcp:8081" "off removes the tunnel"
RE_PROXY_PORT=8081 run device-proxy status
expect_out "no proxy set" "status after off, physical"

fake_reset; fake_device PHONE123; fake_emulator emulator-5554 TestAvd_A
run device-proxy on
expect_rc 1 "several devices and no serial is an error"
run device-proxy on -s PHONE123
expect_rc 0 "-s picks the device"
expect_no_log "-s emulator-5554 shell settings put" "...and only that one"
run device-proxy --serial emulator-5554 status
expect_rc 0 "--serial works before the action"
run device-proxy on -s nope
expect_rc 1 "unknown serial is an error"
run device-proxy on PHONE123
expect_rc 1 "a bare serial is refused"
expect_out "-s SERIAL" "...pointing to -s"

done_testing

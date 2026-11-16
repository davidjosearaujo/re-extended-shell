# shellcheck shell=bash
# Finding a running emulator by AVD name or serial: kill-emulator,
# xapk-installer, and launch-emulator/reset-emulator/release-device -s.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

fake_reset; fake_emulator emulator-5554 TestAvd_A; fake_emulator emulator-5556 TestAvd_B
run kill-emulator TestAvd_B
expect_rc 0 "kill-emulator finds the emulator by name"
expect_log "-s emulator-5556 emu kill" "...and shuts down that one"
expect_no_log "-s emulator-5554 emu kill" "...not the other"
run kill-emulator Nope
expect_rc 1 "kill-emulator: unknown name is an error"

fake_reset; fake_emulator emulator-5554 TestAvd_A
: >"$T_DIR/game.xapk"
run xapk-installer -n Nope "$T_DIR/game.xapk"
expect_rc 1 "xapk-installer -n with an unknown AVD fails"
expect_out "running emulator with AVD name 'Nope'" "...and says why"
run xapk-installer
expect_rc 1 "xapk-installer without a file fails"
run xapk-installer "$T_DIR/missing.xapk"
expect_rc 1 "xapk-installer with a missing file fails"
run xapk-installer notes.txt
expect_rc 1 "xapk-installer rejects other extensions"
: >"$T_DIR/other.xapk"
run xapk-installer "$T_DIR/game.xapk" "$T_DIR/other.xapk"
expect_rc 1 "xapk-installer takes one file at a time"
run xapk-installer -s emulator-5554 -n TestAvd_A "$T_DIR/game.xapk"
expect_rc 1 "xapk-installer refuses -s with -n"
run xapk-merger "$T_DIR/game.xapk" "$T_DIR/other.xapk"
expect_rc 1 "xapk-merger takes one input at a time"
run kill-emulator TestAvd_A TestAvd_B
expect_rc 1 "kill-emulator takes one AVD at a time"
run kill-emulator
expect_rc 1 "kill-emulator without a name fails"
[ -z "$(kill-emulator 2>/dev/null)" ] && pass "...with the error on stderr" || fail "...with the error on stderr"

# --- -s with an emulator serial, alongside a phone ---------------------------
# An 'emulator-NNNN' serial names a running emulator, never a physical device
fake_reset; fake_emulator emulator-5554 TestAvd_A re-ready; fake_device PHONE123
run launch-emulator -s emulator-5554
expect_rc 0 "launch-emulator -s with an emulator serial uses that emulator"
expect_out "TestAvd_A is already running as emulator-5554" "...resolving it to its AVD"
expect_no_out "physical device" "...and never calls it a physical device"
expect_no_log "scrcpy" "...so no scrcpy either"

run launch-emulator -s emulator-5554 --snapshot
expect_rc 1 "launch-emulator -s emulator-NNNN --snapshot fails"
expect_no_out "not physical devices" "...not by claiming the emulator is a phone"
expect_out "reset-emulator -n TestAvd_A" "...but by pointing at reset-emulator"

run launch-emulator -d -s emulator-5554
expect_rc 1 "launch-emulator -d with an emulator serial is a contradiction"
expect_out "-d doesn't apply" "...and says so"

run launch-emulator -s emulator-5558
expect_rc 1 "launch-emulator -s with a serial that isn't running fails"
expect_out "no emulator running as emulator-5558" "...and says which are"
expect_out "emulator-5554 TestAvd_A" "...listing them"

run launch-emulator -s TestAvd_A
expect_rc 0 "launch-emulator -s with an AVD name takes that AVD"
expect_out "TestAvd_A is already running as emulator-5554" "...and finds it running"
run launch-emulator -d -s TestAvd_A
expect_rc 1 "...but -d with an AVD name is a contradiction"
expect_out "is an AVD name, not a physical device" "...and says so"

run release-device -s emulator-5554
expect_rc 1 "release-device refuses an emulator serial"
expect_out "is an emulator" "...saying it only works on a physical device"
run release-device -s TestAvd_A
expect_rc 1 "release-device refuses an AVD name too"
expect_out "is an AVD name" "...for the same reason"

# --- a serial where an AVD name goes, and the other way round ----------------
run kill-emulator emulator-5554
expect_rc 0 "kill-emulator takes an emulator serial"
expect_log "-s emulator-5554 emu kill" "...and shuts that emulator down"

fake_reset; fake_emulator emulator-5554 TestAvd_A re-ready; fake_device PHONE123; fake_avd Idle_Avd re-ready
run launch-emulator emulator-5554
expect_rc 0 "an emulator serial where the AVD name goes means that AVD"
expect_out "TestAvd_A is already running as emulator-5554" "...resolved to its AVD"
run launch-emulator PHONE123
expect_rc 1 "a phone's serial where the AVD name goes fails"
expect_out "launch-emulator -d -s PHONE123" "...with the command to run instead"

# An AVD name where a serial goes names one device just as well
run device-proxy -s TestAvd_A status
expect_rc 0 "device-proxy -s takes an AVD name"
expect_out "is an AVD name, taking the emulator running it (emulator-5554)" "...says which emulator it took"
run device-proxy -n TestAvd_A status
expect_rc 0 "device-proxy -n takes an AVD name"
run device-proxy -n emulator-5554 status
expect_rc 0 "...and an emulator serial"
run device-proxy -s emulator-5554 -n TestAvd_A status
expect_rc 1 "device-proxy with both -s and -n is refused"
run device-proxy -s Idle_Avd status
expect_rc 1 "...but not an AVD that isn't running"
expect_out "no emulator is running it" "...saying exactly that"
expect_out "launch-emulator Idle_Avd" "...and how to start it"

# A target that is the wrong kind altogether
run kill-emulator PHONE123
expect_rc 1 "kill-emulator refuses a phone's serial"
expect_out "is a connected device, not an emulator" "...and says what it is"
run reset-emulator -n PHONE123
expect_rc 1 "reset-emulator refuses a phone's serial"
expect_out "only an emulator has snapshots" "...and says why"
run kill-emulator Idle_Avd
expect_rc 1 "kill-emulator on an AVD that isn't running fails"
expect_out "That AVD exists but isn't running" "...distinguishing it from a typo"
run reset-emulator -n Idle_Avd
expect_rc 1 "reset-emulator on an AVD that isn't running fails"
expect_out "launch-emulator --snapshot Idle_Avd" "...with the command to start it"

# reset-emulator is the one that resets an emulator, phone connected or not
run reset-emulator -n TestAvd_A
expect_rc 0 "reset-emulator -n AVD works with a phone also connected"
run reset-emulator -s emulator-5554
expect_rc 0 "reset-emulator -s emulator-NNNN too"
expect_no_out "physical device" "...with no mention of a physical device"
run reset-emulator -s PHONE123
expect_rc 1 "reset-emulator -s with a phone serial fails"
expect_out "no running emulator matches 'PHONE123'" "...as no emulator matches it"

# --- one AVD, two emulators (--read-only) ------------------------------------
# The AVD name no longer picks one of them silently, and nothing kills the
# process of an emulator that wasn't named
dup_setup() {
    fake_reset
    fake_emulator emulator-5554 Dup re-ready
    echo "emulator-5556|Dup|device" >>"$FAKE_STATE/devices"
    fake_emulator_process 90001 Dup
    fake_emulator_process 90002 Dup
}

dup_setup; run reset-emulator -n Dup
expect_rc 0 "reset-emulator takes the first of two emulators on one AVD"
expect_out "several emulators run the AVD 'Dup'" "...but warns that the name is ambiguous"
expect_out "emulator-5556 Dup" "...listing both"

dup_setup; run reset-emulator -s emulator-5556
expect_rc 0 "...and a serial picks one with no warning"
expect_no_out "several emulators" "...no warning needed"
expect_log "-s emulator-5556 emu avd snapshot load" "...resetting that one"

dup_setup; run kill-emulator Dup
expect_rc 1 "kill-emulator refuses an ambiguous AVD name"
expect_out "name the one to stop by its serial" "...asking for a serial"
expect_no_log "emu kill" "...and stops nothing"

dup_setup; run kill-emulator emulator-5556
expect_rc 0 "kill-emulator by serial stops that emulator"
expect_log "-s emulator-5556 emu kill" "...over adb, which tells the serials apart"

dup_setup; run kill-emulator -f emulator-5556
expect_rc 1 "kill-emulator --force refuses to guess between their processes"
expect_out "stop it without --force" "...and says what to do instead"

# -n on every command that picks a device: names the emulator, and never together with -s
fake_reset; fake_emulator emulator-5554 TestAvd_A; fake_emulator emulator-5556 TestAvd_B
for CMD in apk-pull apk-info app-data app-intent applog; do
    run "$CMD" -s emulator-5554 -n TestAvd_A com.example.app
    expect_rc 1 "$CMD refuses -s with -n"
    expect_out "pass only one of -s SERIAL or -n AVD_NAME" "...and says so"
    run "$CMD" -n Nope com.example.app
    expect_rc 1 "$CMD -n with an unknown AVD fails"
done
run launch-emulator-wireshark -s emulator-5554 -n TestAvd_A
expect_rc 1 "launch-emulator-wireshark refuses -s with -n"
run applog -n TestAvd_B com.example.app
expect_log "-s emulator-5556" "applog -n picks the emulator running that AVD"

done_testing

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
expect_rc 1 "launch-emulator -s with an AVD name fails"
expect_out "is an AVD name, not a device serial" "...and says what to run instead"

run release-device -s emulator-5554
expect_rc 1 "release-device refuses an emulator serial"
expect_out "is an emulator" "...saying it only works on a physical device"

# reset-emulator is the one that resets an emulator, phone connected or not
run reset-emulator -n TestAvd_A
expect_rc 0 "reset-emulator -n AVD works with a phone also connected"
run reset-emulator -s emulator-5554
expect_rc 0 "reset-emulator -s emulator-NNNN too"
expect_no_out "physical device" "...with no mention of a physical device"
run reset-emulator -s PHONE123
expect_rc 1 "reset-emulator -s with a phone serial fails"
expect_out "no running emulator matches 'PHONE123'" "...as no emulator matches it"

done_testing

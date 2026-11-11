# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

fake_reset
run reset-emulator
expect_rc 1 "no emulator running is an error"
expect_out "no running emulator" "no emulator running says so"

fake_reset; fake_emulator emulator-5554 TestAvd_A re-ready
run reset-emulator
expect_rc 0 "one emulator: picked automatically"
expect_log "-s emulator-5554 emu avd snapshot load re-ready" "loads the default snapshot on it"
expect_out "back at snapshot 're-ready'" "reports success"

fake_reset; fake_emulator emulator-5554 TestAvd_A re-ready; fake_emulator emulator-5556 TestAvd_B re-ready
run reset-emulator
expect_rc 1 "several emulators and no target is an error"
expect_out "emulator-5556 TestAvd_B" "lists the running emulators"
expect_no_log "snapshot load" "touches nothing"
run reset-emulator -n TestAvd_B
expect_rc 0 "target by AVD name (-n)"
expect_log "-s emulator-5556 emu avd snapshot load" "loads on the named emulator"
run reset-emulator -s emulator-5554
expect_log "-s emulator-5554 emu avd snapshot load" "target by serial (-s)"
run reset-emulator -s TestAvd_B
expect_rc 1 "-s does not match an AVD name"
run reset-emulator -n nope
expect_rc 1 "unknown target is an error"
expect_out "no running emulator matches 'nope'" "unknown target is named"
run reset-emulator -s emulator-5554 -n TestAvd_B
expect_rc 1 "-s and -n together are refused"
run reset-emulator emulator-5554
expect_rc 1 "a bare target is refused"

fake_reset; fake_emulator emulator-5554 TestAvd_A
run reset-emulator
expect_rc 1 "missing snapshot is an error"
expect_out "kill-emulator TestAvd_A  &&  launch-emulator --snapshot TestAvd_A" "says how to get one"
expect_no_log "snapshot load" "does not ask the emulator"

fake_reset; fake_emulator emulator-5554 TestAvd_A
rm "$ANDROID_AVD_HOME/TestAvd_A.ini"
run reset-emulator
expect_rc 1 "AVD not found on disk: the emulator's own answer decides"
expect_out "didn't load the snapshot" "shows the emulator's refusal"

fake_reset; fake_emulator emulator-5554 TestAvd_A
run reset-emulator --save
expect_rc 0 "--save works without an existing snapshot"
expect_log "emu avd snapshot save re-ready" "--save saves the default snapshot"
[ -d "$ANDROID_AVD_HOME/TestAvd_A.avd/snapshots/re-ready" ] && pass "the snapshot now exists" || fail "the snapshot now exists"
run reset-emulator
expect_rc 0 "...and a reset then works"

fake_reset; fake_emulator emulator-5554 TestAvd_A re-ready
run reset-emulator --save --snapshot app-ready
expect_log "emu avd snapshot save app-ready" "--save --snapshot saves under that name"
expect_no_log "snapshot save re-ready" "...and leaves the default alone"
run reset-emulator --snapshot app-ready
expect_log "emu avd snapshot load app-ready" "--snapshot loads that one"
run reset-emulator --snapshot other
expect_rc 1 "unknown named snapshot is an error"
expect_out "reset-emulator -s emulator-5554 --save --snapshot other" "...and says how to create it"
run reset-emulator --snapshot 'bad name;x'
expect_rc 1 "a snapshot name with odd characters is refused"

fake_reset; fake_emulator emulator-5554 TestAvd_A re-ready
RE_EMULATOR_SNAPSHOT=custom run reset-emulator
expect_out "no 'custom' snapshot" "RE_EMULATOR_SNAPSHOT changes the default"

done_testing

# shellcheck shell=bash
# Finding a running emulator by AVD name: kill-emulator and xapk-installer.
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

done_testing

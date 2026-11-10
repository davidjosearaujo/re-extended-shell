# shellcheck shell=bash
# The shared helpers in lib.sh files.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset

# each case runs in its own bash with the library loaded
lib() { run bash -c ". '$REPO/modules/android/lib.sh'; . '$REPO/modules/binary/lib.sh'; $1"; }

lib 're_version_lt 2.7.0-dirty 2.9 && echo lt'
expect_out "lt" "re_version_lt: 2.7.0-dirty < 2.9"
lib 're_version_lt 2.12.0 2.9 || echo ge'
expect_out "ge" "re_version_lt: 2.12.0 is not < 2.9"
lib 're_version_lt 2.9 2.9 || echo ge'
expect_out "ge" "re_version_lt: equal is not less"

lib 'f() { re_need_arg "$1" "$#"; echo got; }; f -x'
expect_rc 1 "re_need_arg: no value is an error"
lib 'f() { re_need_arg "$1" "$#"; echo got; }; f -x v'
expect_out "got" "re_need_arg: a value passes"

# re_refuse_existing: only a missing path, or a force flag, gets through
: >"$T_DIR/there"
lib "re_refuse_existing '' '$T_DIR/missing' && echo ok"
expect_out "ok" "re_refuse_existing: a missing path passes"
lib "re_refuse_existing '' '$T_DIR/there'"
expect_rc 1 "re_refuse_existing: an existing path is refused"
expect_out "there already exists (use -f to replace it)." "...saying how to force it"
lib "re_refuse_existing '' '$T_DIR/there' 'replace its APKs'"
expect_out "(use -f to replace its APKs)" "...with the caller's wording"
lib "re_refuse_existing 1 '$T_DIR/there' && echo forced"
expect_out "forced" "re_refuse_existing: -f lets it through"

# re_sign_opt: -k/-p/-a fill the signing variables; defaults mean the debug keystore
lib 're_sign_opt --keystore my.jks; re_sign_opt -p secret; re_sign_opt --alias key; echo "$KEYSTORE $KS_PASS $KS_ALIAS $RE_SIGN_GIVEN"'
expect_out "my.jks secret key 1" "re_sign_opt: sets keystore, password and alias"
lib 'echo "[$KEYSTORE] $KS_PASS $KS_ALIAS [$RE_SIGN_GIVEN]"'
expect_out "[] android androiddebugkey []" "re_sign_opt: defaults are the debug keystore"
lib 'KEYSTORE=/nonexistent/x.jks; re_check_keystore'
expect_out "keystore not found: /nonexistent/x.jks" "re_check_keystore: a missing keystore is an error"

# re_settings: one pass over the manifests, optionally for one command
lib 're_settings "" kill-emulator | cut -d"|" -f2'
expect_out "ANDROID_HOME" "re_settings CMD: lists what that command uses"
expect_no_out "JADX" "...and nothing else"
lib 're_settings android | head -n 1 | cut -d"|" -f1,2'
expect_out "android|ANDROID_HOME" "re_settings MODULE: prefixes the module"

printf abc >"$T_DIR/abc"
lib "re_hash sha256 '$T_DIR/abc'"
expect_out "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" "re_hash sha256 of 'abc'"
lib "re_hash md5 '$T_DIR/abc'"
expect_out "900150983cd24fb0d6963f7d28e17f72" "re_hash md5 of 'abc'"
lib "re_hash sha1 '$T_DIR/abc'"
expect_out "a9993e364706816aba3e25717850c26c9cd0d89d" "re_hash sha1 of 'abc'"

fake_avd TestAvd_A
lib 're_avd_dir TestAvd_A'
expect_out "$ANDROID_AVD_HOME/TestAvd_A.avd" "re_avd_dir: a known AVD"
lib 're_avd_dir Nope || echo missing'
expect_out "missing" "re_avd_dir: an unknown AVD fails"
echo "path=/elsewhere/X.avd" >"$ANDROID_AVD_HOME/X.ini"
lib 're_avd_dir X'
expect_out "/elsewhere/X.avd" "re_avd_dir: honours path= in the .ini"
echo "target=android-34" >"$ANDROID_AVD_HOME/Y.ini"
lib 're_avd_dir Y'
expect_out "$ANDROID_AVD_HOME/Y.avd" "re_avd_dir: falls back to <name>.avd"

fake_emulator emulator-5554 TestAvd_A; fake_device PHONE123
lib 're_emulator_serial TestAvd_A'
expect_out "emulator-5554" "re_emulator_serial finds it by AVD name"
lib 're_running_emulators'
expect_out "emulator-5554 TestAvd_A" "re_running_emulators lists emulators"
expect_no_out "PHONE123" "...and not phones"
lib 're_adb_devices --physical'
expect_out "PHONE123" "re_adb_devices --physical lists phones"
expect_no_out "emulator-5554" "...and not emulators"
lib 're_boot_completed emulator-5554 && echo booted'
expect_out "booted" "re_boot_completed"
lib 're_zap_proxy emulator-5554'
expect_out "10.0.2.2:9090" "re_zap_proxy: emulator"
lib 're_zap_proxy PHONE123'
expect_out "127.0.0.1:9090" "re_zap_proxy: phone"

done_testing

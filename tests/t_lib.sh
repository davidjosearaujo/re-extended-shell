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
lib "re_hash sha512 '$T_DIR/abc'"
expect_out "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f" \
    "re_hash sha512 of 'abc'"
if command -v python3 >/dev/null 2>&1; then
    lib "re_hash crc32 '$T_DIR/abc'"
    expect_out "352441c2" "re_hash crc32 of 'abc' is zlib's (what zip tools show)"
else
    skip "re_hash crc32 of 'abc' is zlib's (what zip tools show)" "python3 not installed"
fi
lib "re_hash nonesuch '$T_DIR/abc' || echo unsupported"
expect_out "unsupported" "re_hash: an algorithm no tool can do fails, printing nothing"
if command -v openssl >/dev/null 2>&1; then
    lib "re_hash sha3-256 '$T_DIR/abc'"
    expect_out "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532" "re_hash sha3-256 of 'abc' (openssl)"
else
    skip "re_hash sha3-256 of 'abc' (openssl)" "openssl not installed"
fi

# re_relative_time rounds to the unit that reads naturally
cry() { run bash -c ". '$REPO/modules/crypto/lib.sh'; $1"; }
cry 're_relative_time 1799'
expect_out "in 30 minutes" "re_relative_time: 1799 seconds rounds to 30 minutes"
cry 're_relative_time -7205'
expect_out "2 hours ago" "re_relative_time: a negative number is in the past"
cry 're_relative_time 30'
expect_out "in 30 seconds" "re_relative_time: under a minute stays in seconds"
cry 're_relative_time -86400'
expect_out "1 day ago" "re_relative_time: singular has no 's'"

# re_apk_framework: names the engine from an APK's entry list on stdin
fw() { run bash -c ". '$REPO/modules/android/lib.sh'; printf '%s\n' \"\$1\" | re_apk_framework" _ "$1"; }
fw 'classes.dex
lib/armeabi-v7a/libcocos2djs.so'
expect_out "Cocos2d-x" "re_apk_framework: Cocos by its native lib (the case that slipped through before)"
expect_out "libcocos2djs.so" "...showing the file it matched as evidence"
fw 'classes.dex
assets/bin/Data/Managed/Metadata/global-metadata.dat'
expect_out "Unity (IL2CPP)" "re_apk_framework: Unity IL2CPP from its asset alone (so a split app is still caught)"
fw 'classes.dex
assets/flutter_assets/kernel_blob.bin'
expect_out "Flutter" "re_apk_framework: Flutter from flutter_assets, no .so needed"
fw 'assets/index.android.bundle
lib/arm64-v8a/libhermes.so'
expect_out "React Native" "re_apk_framework: React Native"
expect_out "Hermes" "...noting Hermes when its lib is present"
fw 'lib/arm64-v8a/libgodot_android.so
assets/game.pck'
expect_out "Godot" "re_apk_framework: Godot"
fw 'lib/arm64-v8a/libil2cpp.so
lib/arm64-v8a/libunity.so'
expect_out "Unity (IL2CPP)" "re_apk_framework: IL2CPP wins over Mono when both libs are present"
fw 'classes.dex
res/layout/main.xml'
expect_rc 1 "re_apk_framework: a plain app matches nothing"
expect_eq "$OUT" "" "...and prints nothing"
# Manifest class names catch an engine even when the native lib is renamed
# (the real-world libgame.so case) or the files aren't listed at all
fw 'classes.dex
lib/arm64-v8a/libgame.so
org.cocos2dx.lua.AppActivity'
expect_out "Cocos2d-x" "re_apk_framework: Cocos by its manifest class, despite a renamed libgame.so"
expect_out "org.cocos2dx.lua.AppActivity" "...showing the class as evidence"
fw 'com.unity3d.player.UnityPlayerActivity'
expect_out "Unity" "re_apk_framework: Unity by its player class, no files needed"
fw 'io.flutter.embedding.android.FlutterActivity'
expect_out "Flutter" "re_apk_framework: Flutter by its manifest class"
fw 'mono.MonoRuntimeProvider'
expect_out "Xamarin" "re_apk_framework: Xamarin by its runtime provider"
fw 'org.qtproject.qt.android.bindings.QtActivity'
expect_out "Qt" "re_apk_framework: Qt by its activity class"

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
lib 're_proxy_address emulator-5554'
expect_out "10.0.2.2:9090" "re_proxy_address: emulator"
lib 're_proxy_address PHONE123'
expect_out "127.0.0.1:9090" "re_proxy_address: phone"

# The proxy settings, and the older names they fall back to
RE_ZAP_PORT=7777 lib 'echo "port=$RE_PROXY_PORT"'
expect_out "port=7777" "RE_ZAP_PORT still sets the proxy port"
RE_ZAP_PORT=7777 RE_PROXY_PORT=8080 lib 'echo "port=$RE_PROXY_PORT"'
expect_out "port=8080" "...but RE_PROXY_PORT wins"
# (certs/zap_root_ca.cer, from an older version, is used while there's no proxy_ca.cer)
DEFAULT_CERT="$REPO/certs/proxy_ca.cer"
[ -f "$DEFAULT_CERT" ] || [ ! -f "$REPO/certs/zap_root_ca.cer" ] || DEFAULT_CERT="$REPO/certs/zap_root_ca.cer"
lib 'echo "port=$RE_PROXY_PORT cert=$RE_PROXY_CERT"'
expect_out "port=9090 cert=$DEFAULT_CERT" "defaults: port 9090, certs/proxy_ca.cer"
RE_ZAP_CERT=/x/old.cer lib 'echo "cert=$RE_PROXY_CERT"'
expect_out "cert=/x/old.cer" "RE_ZAP_CERT still sets the certificate, even if the file is missing"
RE_ZAP_CERT=/x/old.cer RE_PROXY_CERT=/x/new.cer lib 'echo "cert=$RE_PROXY_CERT"'
expect_out "cert=/x/new.cer" "...but RE_PROXY_CERT wins"

done_testing

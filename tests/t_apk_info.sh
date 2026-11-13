# shellcheck shell=bash
# apk-info, on tests/fixtures/target-apk: the real aapt2 output of an APK built
# from AndroidManifest.xml.src there (exported defaults, permissions, deep
# links, a network security config with pins and debug-overrides).
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

# fixture_apk: the fake aapt2 answers with the fixture, for any APK
fixture_apk() {
    mkdir -p "$FAKE_STATE/aapt2"
    cp "$TESTS/fixtures/target-apk/"* "$FAKE_STATE/aapt2/"
}

fake_reset; fixture_apk
cd "$T_DIR" || exit 1
echo fake >target.apk
run apk-info target.apk
expect_rc 0 "an APK file: runs"
expect_out "Package      com.example.target" "reads the package"
expect_out "Version      2.1 (code 7)" "...the version"
expect_out "SDK          min 16, target 23" "...the SDK levels"
expect_out "skipped (apksigner not found" "without apksigner, skips the signature"
expect_out "debuggable   yes" "flags debuggable"
expect_out "allowBackup  no" "reads allowBackup"
expect_out "cleartext    allowed (usesCleartextTraffic)" "reads usesCleartextTraffic"
expect_out "File         res/xml/nsc.xml" "finds the network security config through the resource table"
expect_out "base: cleartext not allowed, trusts system" "...its base config"
expect_out "*.api.example.com, example.org: pinned (2 pins, expire 2030-01-01)" "...its pinned domains"
expect_out "debug-overrides (active: debuggable): trusts user" "...and debug-overrides, active as the app is debuggable"
expect_out "android.permission.READ_SMS (sensitive)" "marks sensitive permissions"
expect_out "com.example.target.WEAK (normal, any app can get it)" "explains a declared normal permission"
expect_out "com.example.target.STRONG (signature)" "...and a signature one"
expect_out "Exported components (7 of 10)" "counts the exported components"
expect_out ".MainActivity  (launcher)" "marks the launcher"
expect_out "alias of .MainActivity" "follows an activity-alias"
expect_out "content://com.example.target.data content://com.example.target.alt" "lists every provider authority"
expect_out "permission com.example.target.WEAK (normal, any app can get it)" "a weak permission on a component is called out"
expect_no_out ".internal.Secret" "hides components that aren't exported"
expect_no_out ".Hidden" "...including a receiver without a filter"
expect_out "https://example.com:8443/app*  -> .DeepLinkActivity" "lists deep links, with port and path prefix"
expect_out "target://open/app*" "...combining the filter's data elements"
expect_no_out "nodefault:" "an activity filter without the DEFAULT category is no deep link"
expect_out "Start one with: app-intent com.example.target <N>" "points to app-intent"

# The provider without exported= is exported on API 16, not on later ones
grep -q '^  8   provider       .DataProvider' <<<"$OUT" && pass "a provider is exported by default on API 16" \
    || fail "a provider is exported by default on API 16" "$OUT"
sed 's/targetSdkVersion(0x01010270)=23/targetSdkVersion(0x01010270)=30/; s/minSdkVersion(0x0101020c)=16/minSdkVersion(0x0101020c)=21/' \
    "$TESTS/fixtures/target-apk/AndroidManifest.xml.tree" >"$FAKE_STATE/aapt2/AndroidManifest.xml.tree"
run apk-info target.apk
expect_out "Exported components (6 of 10)" "...but not on later ones"
expect_no_out "debug-overrides (inactive" "debug-overrides stay active while debuggable"
fixture_apk

run apk-info --all target.apk
expect_out "Other components (3)" "--all lists the rest"
expect_out ".internal.Secret" "...by name"
expect_out "As root, these can be started too: app-intent --root" "...and how to reach them"

# From the device, by package name
fake_device PHONE123
mkdir -p "$FAKE_STATE/files/data/app/fake"
echo fake >"$FAKE_STATE/files/data/app/fake/base.apk"
run apk-info com.example.target
expect_rc 0 "a package name: runs"
expect_log "-s PHONE123 pull /data/app/fake/base.apk" "...pulling its base APK"
expect_out "Source       com.example.target on PHONE123" "...and says where it came from"

# Errors
run apk-info missing.apk
expect_out "file not found: missing.apk" "a missing APK file"
run apk-info 'com.x;reboot'
expect_out "not a valid package name" "a package name with shell characters is refused"
run apk-info -s PHONE123 target.apk
expect_out "-s only applies to a package name" "-s with a file is refused"
: >bundle.xapk
run apk-info bundle.xapk
expect_out "split APK bundle" "a bundle points to xapk-merger"
# The Framework section, end to end: the fake aapt2 answers on the manifest
# filename, so a real zip (which unzip can list) named like an APK works. Needs
# zip to build one.
if command -v zip >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
    fixture_apk
    mkdir -p game/lib/armeabi-v7a game/assets
    : >game/classes.dex; : >game/AndroidManifest.xml
    : >game/lib/armeabi-v7a/libcocos2djs.so
    rm -f game.apk && ( cd game && zip -qr ../game.apk . )
    run apk-info game.apk
    expect_rc 0 "a real APK: runs"
    expect_out "== Framework ==" "has a Framework section of its own"
    expect_out "Engine       Cocos2d-x" "names the engine (the libcocos2djs.so case)"
    expect_out "Evidence     lib/armeabi-v7a/libcocos2djs.so" "...with the file it matched"
    expect_out "== Code ==" "still has a separate Code section"
    expect_out "libcocos2djs.so" "...listing the native library"

    # A plain app: the section says so rather than going quiet
    mkdir -p plain
    : >plain/classes.dex; : >plain/AndroidManifest.xml
    rm -f plain.apk && ( cd plain && zip -qr ../plain.apk . )
    run apk-info plain.apk
    expect_out "none detected (plain Java/Kotlin dex)" "a plain app says no framework was detected"
else
    skip "Framework section end to end" "zip/unzip not installed"
fi

rm "$FAKE_STATE/aapt2/AndroidManifest.xml.tree"
run apk-info target.apk
expect_rc 1 "an unreadable manifest fails"
expect_out "could not read the manifest" "...and says so"

done_testing

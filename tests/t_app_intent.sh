# shellcheck shell=bash
# app-intent, with the components of tests/fixtures/target-apk (see t_apk_info.sh)
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

setup() {
    fake_reset; fake_device PHONE123
    mkdir -p "$FAKE_STATE/aapt2" "$FAKE_STATE/files/data/app/fake"
    cp "$TESTS/fixtures/target-apk/"* "$FAKE_STATE/aapt2/"
    echo fake >"$FAKE_STATE/files/data/app/fake/base.apk"
}
P=com.example.target

setup
run app-intent $P
expect_rc 0 "lists the exported components"
expect_out "2   activity       .DeepLinkActivity" "...numbered, with short names"
expect_out "5   service        .SyncService  (needs com.example.target.WEAK)" "...with the permission they need"
expect_out "content://com.example.target.data" "...and provider URIs"
expect_no_out ".internal.Secret" "...but not the internal ones"
run app-intent --all $P
expect_out "3   activity       .internal.Secret  (not exported)" "--all lists the internal ones too"

# Starting components, as the shell user (the fake adbd is root)
setup
run app-intent $P 2 --data 'target://open/x?a=b' -e 'k=v w'
expect_rc 0 "starts an activity by number"
expect_log "shell su shell am start -W -n 'com.example.target/com.example.target.DeepLinkActivity' -d 'target://open/x?a=b' --es 'k' 'v w'" \
    "...with am start, as the shell user, data and extras quoted"
run app-intent $P .SyncService
expect_log "am startservice -n 'com.example.target/com.example.target.SyncService'" "a service by .ShortName"
run app-intent $P BootReceiver --action com.example.target.SYNC
expect_log "am broadcast -n 'com.example.target/com.example.target.BootReceiver' -a 'com.example.target.SYNC'" "a receiver by class name, with an action"
run app-intent $P 8 -- --projection name
expect_log "content query --uri 'content://com.example.target.data/' '--projection' 'name'" "a provider: content query on its first authority, -- arguments passed on"
run app-intent $P 8 --data content://com.example.target.alt/users
expect_log "content query --uri 'content://com.example.target.alt/users'" "...or on --data"
run app-intent $P --data 'target://open/'
expect_log "am start -W -p 'com.example.target' -a 'android.intent.action.VIEW' -d 'target://open/'" "--data alone sends a VIEW intent to the package"
run app-intent $P 2 -e "q=it's"
expect_log "--es 'q' 'it'\\''s'" "single quotes in values are escaped"

# Who runs it, when adbd isn't root, or can't switch to the shell user
setup
FAKE_ADBD=shell run app-intent $P 2
expect_out "As the shell user" "adbd not root: runs as the shell user"
expect_no_log "su shell am" "...directly, without su"
setup
FAKE_ADBD=nosu run app-intent $P 2
expect_out "can't switch to the shell user, so this runs as root" "adbd root without a way to the shell user: warns"
expect_log "shell am start -W -n 'com.example.target/com.example.target.DeepLinkActivity'" "...and still runs it"

# What isn't exported
setup
run app-intent $P 3
expect_out "is not exported, so this should be refused" "warns about a component that isn't exported"
expect_log "su shell am start" "...and still runs it as the shell user"
setup
run app-intent --root $P 3
expect_log "shell am start -W -n 'com.example.target/com.example.target.internal.Secret'" "--root starts it"
expect_no_log "su shell am" "...as root"

# Errors
setup
run app-intent $P Nope
expect_out "no component 'Nope'" "an unknown component"
run app-intent $P 8 -e a=b
expect_out "-e doesn't apply to a provider" "-e with a provider"
run app-intent $P -e a=b
expect_out "need a component" "extras without a component"
run app-intent --root $P
expect_out "--root needs a component" "--root without a component"
run app-intent $P 2 -e novalue
expect_out "takes KEY=VALUE" "-e without ="
run app-intent $P 2 extra
expect_out "unexpected argument: extra" "a third operand"

done_testing

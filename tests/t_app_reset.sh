# shellcheck shell=bash
# app-reset: stops an app, clears its data, and revokes (or grants) its
# runtime permissions, reading them from dumpsys.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

# What 'dumpsys package' says about an app on Android 14, cut down: what it
# asks for, its install-time permissions, then each user's runtime ones
dumpsys() {
    cat >"$FAKE_STATE/dumpsys.com.example.app" <<'TXT'
Packages:
  Package [com.example.app] (2a3b4c5):
    userId=10190
    requested permissions:
      android.permission.INTERNET
      android.permission.CAMERA
      android.permission.ACCESS_FINE_LOCATION: restricted=true
      android.permission.POST_NOTIFICATIONS
    install permissions:
      android.permission.INTERNET: granted=true
    User 0: ceDataInode=12345 installed=true hidden=false
      gids=[3003]
      runtime permissions:
        android.permission.POST_NOTIFICATIONS: granted=false, flags=[ USER_SENSITIVE_WHEN_GRANTED ]
        android.permission.ACCESS_FINE_LOCATION: granted=true, flags=[ USER_SET ]
        android.permission.CAMERA: granted=true, flags=[ USER_SET ]
    User 10: ceDataInode=0 installed=true hidden=false
      runtime permissions:
        android.permission.POST_NOTIFICATIONS: granted=true, flags=[ USER_SET ]
TXT
}

fake_reset; fake_emulator emulator-5554 TestAvd_A; dumpsys
run app-reset
expect_rc 1 "no package is a usage error"
expect_out "missing <PACKAGE>" "...naming what's missing"
run app-reset 'com.example;rm'
expect_rc 1 "a package name with shell characters is refused"
run app-reset --keep-perms --grant-all com.example.app
expect_rc 1 "--keep-perms and --grant-all together are refused"

run app-reset com.example.app
expect_rc 0 "app-reset resets an app"
expect_log "shell am force-stop com.example.app" "...stopping it"
expect_log "shell pm clear com.example.app" "...clearing its data"
expect_log "pm revoke com.example.app" "...and revoking its permissions"
expect_out "Data         cleared" "...and says so"
expect_out "reset, 2 revoked" "...counting the runtime permissions that were granted"
expect_out "android.permission.CAMERA" "...naming them"
expect_no_out "POST_NOTIFICATIONS" "...only the first user's granted ones"
expect_no_log "monkey" "...without launching it"

fake_reset; fake_emulator emulator-5554 TestAvd_A; dumpsys
echo android.permission.INTERNET >"$FAKE_STATE/pm-refuses"
run app-reset --grant-all --start -n TestAvd_A com.example.app
expect_rc 0 "--grant-all grants what it asks for"
expect_log "pm grant com.example.app" "...through pm grant"
expect_out "granted 3" "...counting what pm accepted (not the install-time INTERNET)"
expect_log "monkey -p com.example.app" "--start launches it"

fake_reset; fake_emulator emulator-5554 TestAvd_A; dumpsys
run app-reset --keep-data --keep-perms com.example.app
expect_rc 0 "--keep-data --keep-perms only stops it"
expect_no_log "pm clear" "...keeping its data"
expect_no_log "pm revoke" "...and its permissions"
expect_out "Data         kept" "...and says so"

fake_reset; fake_emulator emulator-5554 TestAvd_A; dumpsys
: >"$FAKE_STATE/pm-clear-fails"
run app-reset com.example.app
expect_rc 1 "a refused pm clear is an error"
expect_out "could not clear the data" "...saying so"

done_testing

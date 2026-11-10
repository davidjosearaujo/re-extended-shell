# shellcheck shell=bash
# Commands that write files: -o picks the output, an existing one needs -f.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

fake_reset
cd "$T_DIR" || exit 1

: >app.apk; : >app_patched.apk
run apk-patch app.apk
expect_rc 1 "apk-patch refuses to replace its output"
expect_out "app_patched.apk already exists (use -f to replace it)" "...and says to use -f"
: >custom.apk
run apk-patch -o custom.apk app.apk
expect_out "custom.apk already exists" "apk-patch checks the -o output too"

: >game.xapk; : >game_merged.apk
run xapk-merger game.xapk
expect_rc 1 "xapk-merger refuses to replace its output"
expect_out "game_merged.apk already exists (use -f to replace it)" "...and says to use -f"
rm game_merged.apk; mkdir game_merged_obb
run xapk-merger game.xapk
expect_rc 1 "xapk-merger refuses to replace an OBB folder"
expect_out "game_merged_obb already exists" "...and names it"

fake_reset; fake_device PHONE123
cd "$T_DIR" || exit 1
run apk-pull -o pulled com.example.app
expect_rc 0 "apk-pull -o pulls into that directory"
expect_log "pull /data/app/fake/base.apk pulled/base.apk" "...the APKs land there"
: >pulled/base.apk
run apk-pull -o pulled com.example.app
expect_rc 1 "apk-pull refuses to replace a filled directory"
run apk-pull -o pulled -f com.example.app
expect_rc 0 "...unless given -f"
run apk-pull -k my.jks com.example.app
expect_rc 1 "apk-pull -k without --merge is refused"
expect_out "only apply with --merge" "...and says why"
fake_reset; fake_device PHONE123
cd "$T_DIR" || exit 1
run apk-pull --merge -k missing.jks com.example.app
expect_rc 1 "apk-pull --merge with a missing keystore fails before pulling"
expect_no_log "pull /data/app" "...without pulling anything"

done_testing

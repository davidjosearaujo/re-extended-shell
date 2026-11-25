# shellcheck shell=bash
# frida-server's hiding: the random, persisted on-device name and the
# Florida/stock source selection. Device and network are faked.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
cd "$T_DIR" || exit 1

FRIDA_DIR="$HOME/.local/share/re-extended-shell/frida"
NAME_FILE="$FRIDA_DIR/server-name"
mkdir -p "$FRIDA_DIR"
# frida --version is faked to 16.0.0, the device ABI to x86_64. The cache name
# carries the source; florida-zygisk's asset is version-less (frida-server-android-*).
ZYGISK="florida-zygisk-server-16.0.0-android-x86_64"
STOCK="frida-server-16.0.0-android-x86_64"

# A fake curl so --refresh can "download": writes a build of the right format,
# or fails when FAKE_CURL_FAIL is set (to stand in for a missing release).
mkdir -p "$T_DIR/bin"
cat >"$T_DIR/bin/curl" <<'SH'
#!/usr/bin/env bash
echo "curl $*" >>"${FAKE_STATE:?}/log"
[ -z "${FAKE_CURL_FAIL:-}" ] || exit 22
dest="" url=""
while [ "$#" -gt 0 ]; do
    case "$1" in -o) dest="$2"; shift 2 ;; -*) shift ;; *) url="$1"; shift ;; esac
done
case "$url" in
    *.gz) printf 'fakebin' | gzip -c >"$dest" ;;
    *.xz) printf 'fakebin' | xz   -c >"$dest" ;;
    *)    printf 'fakebin' >"$dest" ;;
esac
SH
chmod +x "$T_DIR/bin/curl"
export PATH="$T_DIR/bin:$PATH"

# --- Florida (florida-zygisk) by default, under a random name ----------------
fake_reset; fake_emulator emulator-5554 TestAvd_A
echo fakebin >"$FRIDA_DIR/$ZYGISK"
run frida-server --push-only
expect_rc 0 "frida-server --push-only with the Florida build cached"
expect_log "push $FRIDA_DIR/$ZYGISK" "pushes the florida-zygisk build by default"
if [ -s "$NAME_FILE" ]; then pass "a random on-device name is persisted"; else fail "a random on-device name is persisted"; fi
NAME=$(cat "$NAME_FILE")
expect_eq "$NAME" "${NAME#frida-server}" "...and it isn't the give-away 'frida-server'"
expect_log "/data/local/tmp/re-ext/$NAME" "pushes under the random name"
expect_no_log "re-ext/frida-server" "...not /data/local/tmp/re-ext/frida-server"

# The name is stable across invocations, and the same build isn't pushed twice
run frida-server --push-only
expect_eq "$(cat "$NAME_FILE")" "$NAME" "the name persists across runs"
expect_out "is already on" "...and the same build isn't re-pushed"
expect_eq "$(grep -c "push $FRIDA_DIR/$ZYGISK" "$FAKE_STATE/log")" 1 "...only pushed once"

# Switching the source re-pushes, even at the same Frida version
echo fakebin >"$FRIDA_DIR/$STOCK"
export RE_FRIDA_SOURCE=frida
run frida-server --push-only
expect_log "push $FRIDA_DIR/$STOCK" "a different RE_FRIDA_SOURCE re-pushes at the same version"
unset RE_FRIDA_SOURCE

# --- a pinned RE_FRIDA_NAME wins and doesn't disturb the persisted one -------
export RE_FRIDA_NAME=mediaserverd
run frida-server --push-only
expect_log "/data/local/tmp/re-ext/mediaserverd" "a pinned RE_FRIDA_NAME is used"
expect_eq "$(cat "$NAME_FILE")" "$NAME" "...and the persisted name is left alone"
unset RE_FRIDA_NAME

# --- --refresh rotates the name ---------------------------------------------
run frida-server --refresh --push-only
expect_rc 0 "frida-server --refresh re-downloads"
expect_log "thelok1s/florida-zygisk/releases/download/16.0.0/frida-server-android-x86_64.gz" "downloads the florida-zygisk build"
ROTATED=$(cat "$NAME_FILE")
if [ "$ROTATED" != "$NAME" ]; then pass "--refresh rotates the on-device name"; else fail "--refresh rotates the on-device name" "still $NAME"; fi
expect_log "/data/local/tmp/re-ext/$ROTATED" "...and pushes under the new name"

# --- the stock source -------------------------------------------------------
fake_reset; fake_emulator emulator-5554 TestAvd_A
echo fakebin >"$FRIDA_DIR/$STOCK"
export RE_FRIDA_SOURCE=frida
run frida-server --push-only
expect_rc 0 "RE_FRIDA_SOURCE=frida uses the stock build"
expect_log "push $FRIDA_DIR/$STOCK" "...pushes the stock frida-server build"
expect_no_log "push $FRIDA_DIR/$ZYGISK" "...not the Florida one"
unset RE_FRIDA_SOURCE

# --- a bad source is rejected -----------------------------------------------
fake_reset; fake_emulator emulator-5554 TestAvd_A
export RE_FRIDA_SOURCE=bogus
run frida-server --push-only
unset RE_FRIDA_SOURCE
expect_rc 1 "an unknown RE_FRIDA_SOURCE is refused"
expect_out "RE_FRIDA_SOURCE must be" "...with the valid values"

# --- Florida without a matching release explains the way out -----------------
fake_reset; fake_emulator emulator-5554 TestAvd_A
rm -f "$FRIDA_DIR/$ZYGISK"
export FAKE_CURL_FAIL=1
run frida-server --push-only
unset FAKE_CURL_FAIL
expect_rc 1 "a missing Florida build is a clean error"
expect_out "florida-zygisk has no server build" "...naming the source"
expect_out "RE_FRIDA_SOURCE=frida" "...and the stock fallback"

done_testing

# shellcheck shell=bash
# RE Extended Shell - helpers for the Android module's commands (bin/).
# Sourced by those scripts (always bash), never by your interactive shell.
# Same portability rules as core/lib.sh: bash 3.2, GNU and BSD tools.

# shellcheck source=../core/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/../core/lib.sh"
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_ANDROID_DIR="$RE_EXT_HOME/modules/android"

# Settings: export any of these (e.g. in local/android.sh) to override.
RE_ZAP_SNAPSHOT="${RE_ZAP_SNAPSHOT:-zap-ready}"
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_DEVICE_DIR="/data/local/tmp/re-ext"   # where files get pushed on the device
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_APKEDITOR_DL="$RE_DATA_DIR/apkeditor/APKEditor.jar"   # xapk-merger's download

# Serials of connected, authorised devices. --physical skips emulators.
re_adb_devices() {
    if [ "${1:-}" = "--physical" ]; then
        adb devices | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ { print $1 }'
    else
        adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'
    fi
}

# Prints "SERIAL AVD_NAME" for every running emulator adb knows about.
re_running_emulators() {
    local S NAME
    for S in $(re_adb_devices | grep '^emulator-'); do
        NAME=$(adb -s "$S" emu avd name 2>/dev/null | head -n 1 | tr -d '\r')
        echo "$S ${NAME:-?}"
    done
}

# Exits if FILE is a split-APK bundle: those have to be merged first.
re_reject_bundle() {
    case "$1" in
        *.[xX][aA][pP][kK]|*.[aA][pP][kK][sS]|*.[zZ][iI][pP])
            re_die "$1 is a split APK bundle, merge it first: xapk-merger \"$1\"" ;;
    esac
}

# Resolves a configurable tool command (e.g. $JADX) into the array RE_TOOL_CMD
# and succeeds if it looks runnable. The value may carry arguments, so it's
# word-split: "flatpak run com.github.skylot.jadx", a bare "jadx" on PATH, or an
# absolute path all work (command -v accepts a path too). Spaces in a path
# aren't supported; set JADX to a wrapper or symlink in that rare case.
# Usage: re_tool_cmd "${JADX:-jadx}"  &&  "${RE_TOOL_CMD[@]}" ...
re_tool_cmd() {
    # shellcheck disable=SC2206  # the setting is meant to be split into words
    RE_TOOL_CMD=( $1 )
    [ "${#RE_TOOL_CMD[@]}" -gt 0 ] || return 1
    command -v "${RE_TOOL_CMD[0]}" >/dev/null 2>&1
}

# Prints the serial to use: the given one if it's connected, otherwise the only
# connected device. Errors go to stderr.
# Usage: re_pick_device [--physical] <caller> [SERIAL]
re_pick_device() {
    local FILTER=""
    if [ "${1:-}" = "--physical" ]; then FILTER="--physical"; shift; fi
    local CALLER="$1" SERIAL="${2:-}" KIND="device"
    [ -n "$FILTER" ] && KIND="physical device"
    if [ -z "$SERIAL" ]; then
        local DEVICES=() LINE
        while IFS= read -r LINE; do
            [ -n "$LINE" ] && DEVICES+=("$LINE")
        done < <(re_adb_devices $FILTER)
        case "${#DEVICES[@]}" in
            0)  echo "Error: no $KIND connected (check 'adb devices' and that USB debugging is authorised)." >&2
                return 1 ;;
            1)  SERIAL="${DEVICES[0]}" ;;
            *)  echo "Error: several devices connected, pick one with: $CALLER <SERIAL>" >&2
                printf '  %s\n' "${DEVICES[@]}" >&2
                return 1 ;;
        esac
    fi
    if [ "$(adb -s "$SERIAL" get-state 2>/dev/null)" != "device" ]; then
        echo "Error: device '$SERIAL' is not connected or not authorised (see 'adb devices')." >&2
        return 1
    fi
    echo "$SERIAL"
}

# Succeeds if adb shell on SERIAL already runs as root.
re_adb_is_root() {
    [ "$(adb -s "$1" shell id -u 2>/dev/null | tr -d '\r')" = "0" ]
}

# Prints how to run commands as root on SERIAL: 'adbd' (adb shell is already
# root) or 'su' (Magisk/KernelSU). With --adb-root it first tries 'adb root',
# which works on emulators and userdebug builds. Fails without root.
# Usage: re_root_mode [--adb-root] SERIAL
re_root_mode() {
    local TRY="" SERIAL
    if [ "$1" = "--adb-root" ]; then TRY=1; shift; fi
    SERIAL="$1"
    if re_adb_is_root "$SERIAL"; then
        echo adbd; return 0
    fi
    if [ -n "$TRY" ]; then
        echo "Restarting adb daemon with root privileges..." >&2
        if ! adb -s "$SERIAL" root 2>&1 | grep -q "cannot run as root"; then
            for _ in $(seq 1 15); do
                sleep 1
                if re_adb_is_root "$SERIAL"; then echo adbd; return 0; fi
            done
        fi
    fi
    # Retail phones rooted with Magisk/KernelSU only offer su
    adb -s "$SERIAL" wait-for-device
    [ -n "$(adb -s "$SERIAL" shell 'command -v su' 2>/dev/null | tr -d '\r')" ] || return 1
    echo "adbd isn't root on this build, trying su (approve the root prompt on the device if one appears)..." >&2
    if [ "$(adb -s "$SERIAL" shell "su -c 'id -u'" 2>/dev/null | tr -d '\r')" = "0" ]; then
        echo su; return 0
    fi
    return 1
}

# Runs a shell command on SERIAL as root, MODE being what re_root_mode printed.
# The command must not contain single quotes.
# Usage: re_root_shell SERIAL MODE COMMAND
re_root_shell() {
    if [ "$2" = "su" ]; then
        adb -s "$1" shell "su -c '$3'"
    else
        adb -s "$1" shell "$3"
    fi
}

# Exits unless PACKAGE is installed on SERIAL, listing similar package names.
# Usage: re_require_package SERIAL PACKAGE
re_require_package() {
    local SERIAL="$1" PKG="$2" MATCHES
    if [ -n "$(adb -s "$SERIAL" shell pm path "$PKG" 2>/dev/null | tr -d '\r')" ]; then
        return 0
    fi
    MATCHES=$(adb -s "$SERIAL" shell pm list packages 2>/dev/null | tr -d '\r' \
        | sed 's/^package://' | grep -iF -- "$PKG" | sort | head -n 15)
    echo "Error: package '$PKG' is not installed on $SERIAL." >&2
    if [ -n "$MATCHES" ]; then
        echo "Did you mean:" >&2
        sed 's/^/  /' <<<"$MATCHES" >&2
    fi
    exit 1
}

# Prints the path of an SDK build tool (apksigner, zipalign, ...): on PATH, or
# from the newest build-tools of the SDK.
re_find_build_tool() {
    local TOOL="$1" SDK LATEST
    if command -v "$TOOL" >/dev/null 2>&1; then command -v "$TOOL"; return 0; fi
    for SDK in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk" "$HOME/Library/Android/sdk"; do
        [ -n "$SDK" ] || continue
        LATEST=$(ls -d "$SDK"/build-tools/*/ 2>/dev/null | sort -V | tail -n 1)
        if [ -n "$LATEST" ] && [ -x "${LATEST}${TOOL}" ]; then
            echo "${LATEST}${TOOL}"
            return 0
        fi
    done
    return 1
}

# Zipaligns IN (if zipalign is available), signs it into OUT with apksigner,
# then verifies OUT. Without a keystore, signs with the Android debug keystore,
# creating it if needed.
# Usage: re_sign_apk IN OUT [KEYSTORE [KS_PASS [KS_ALIAS]]]
re_sign_apk() {
    local IN="$1" OUT="$2" KEYSTORE="${3:-}" KS_PASS="${4:-android}" KS_ALIAS="${5:-androiddebugkey}"
    local APKSIGNER ZIPALIGN TO_SIGN="$1" ALIGNED=""
    APKSIGNER=$(re_find_build_tool apksigner) || re_die "'apksigner' not found (PATH or \$ANDROID_HOME/build-tools)."

    # zipalign MUST happen before apksigner (v2+ signatures cover the whole file)
    if ZIPALIGN=$(re_find_build_tool zipalign); then
        echo "Aligning APK..."
        ALIGNED=$(mktemp "${TMPDIR:-/tmp}/re-aligned.XXXXXX")
        if "$ZIPALIGN" -p -f 4 "$IN" "$ALIGNED"; then
            TO_SIGN="$ALIGNED"
        else
            echo "Warning: zipalign failed, signing unaligned APK."
        fi
    else
        echo "Warning: 'zipalign' not found, skipping alignment."
    fi

    if [ -z "$KEYSTORE" ]; then
        KEYSTORE="$HOME/.android/debug.keystore"
        KS_PASS="android"
        KS_ALIAS="androiddebugkey"
        if [ ! -f "$KEYSTORE" ]; then
            re_require keytool
            echo "Creating debug keystore at $KEYSTORE..."
            mkdir -p "$HOME/.android"
            keytool -genkeypair -keystore "$KEYSTORE" -storepass android -keypass android \
                -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
                -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1 \
                || { rm -f "$ALIGNED"; re_die "failed to create debug keystore."; }
        fi
    fi

    echo "Signing with '$KEYSTORE' (alias: $KS_ALIAS)..."
    if ! "$APKSIGNER" sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --ks-key-alias "$KS_ALIAS" \
            --v4-signing-enabled false --out "$OUT" "$TO_SIGN"; then
        rm -f "$ALIGNED"
        echo "APK signing failed." >&2
        return 1
    fi
    rm -f "$ALIGNED"

    if "$APKSIGNER" verify "$OUT" >/dev/null 2>&1; then
        echo "Signature verified."
    else
        echo "Warning: apksigner verify reported problems."
    fi
}

# Converts $RE_ZAP_CERT (PEM or DER) into the <subject_hash_old>.0 file Android
# expects, inside OUT_DIR. Sets RE_CERT_HASH and RE_CERT_FILE.
# Usage: re_prepare_cert OUT_DIR
re_prepare_cert() {
    local OUT_DIR="$1" FORM
    re_require_zap_cert
    re_require openssl
    for FORM in PEM DER; do
        if RE_CERT_HASH=$(openssl x509 -inform "$FORM" -in "$RE_ZAP_CERT" -noout -subject_hash_old 2>/dev/null); then
            RE_CERT_FILE="$OUT_DIR/$RE_CERT_HASH.0"
            openssl x509 -inform "$FORM" -in "$RE_ZAP_CERT" -outform PEM -out "$RE_CERT_FILE" \
                || re_die "could not convert $RE_ZAP_CERT to PEM."
            return 0
        fi
    done
    re_die "$RE_ZAP_CERT is not a PEM or DER X.509 certificate."
}

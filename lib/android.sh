# shellcheck shell=bash
# RE Extended Shell - helpers for the Android commands in bin/.
# Sourced by those scripts (always bash), never by your interactive shell.
# Same portability rules as common.sh: bash 3.2, GNU and BSD tools.

# shellcheck source=common.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

# Settings: export any of these (e.g. in local/android.sh) to override.
RE_ZAP_SNAPSHOT="${RE_ZAP_SNAPSHOT:-zap-ready}"
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_DEVICE_DIR="/data/local/tmp/re-ext"   # where files get pushed on the device

# Serials of connected, authorised devices. --physical skips emulators.
re_adb_devices() {
    if [ "${1:-}" = "--physical" ]; then
        adb devices | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ { print $1 }'
    else
        adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'
    fi
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

# shellcheck shell=bash
# RE Extended Shell - helpers for the Android module's commands (bin/).
# Sourced by those scripts (always bash), never by your interactive shell.
# Same portability rules as core/lib.sh: bash 3.2, GNU and BSD tools.

# shellcheck source=../core/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/../core/lib.sh"
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_ANDROID_DIR="$RE_EXT_HOME/modules/android"

# Settings: export any of these (e.g. in local/env.sh) to override.
RE_EMULATOR_SNAPSHOT="${RE_EMULATOR_SNAPSHOT:-re-ready}"
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_DEVICE_DIR="/data/local/tmp/re-ext"   # where files get pushed on the device
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_APKEDITOR_DL="$RE_DATA_DIR/apkeditor/APKEditor.jar"   # xapk-merger's download

# Which build of frida-server to push:
#   florida-zygisk (default) - the Florida anti-detection build, which hides the
#       server from the pinning and anti-Frida checks apps run, taken from
#       thelok1s/florida-zygisk, whose CI rebuilds it weekly against the latest
#       Frida (we use its plain server binary, not the Magisk module)
#   frida - the stock upstream build
# florida-zygisk only publishes a build for some Frida versions, so if yours
# isn't there, frida-server says so and 'frida' is the way out.
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_FRIDA_SOURCE="${RE_FRIDA_SOURCE:-florida-zygisk}"
# Where the random on-device name (below) is remembered, under the cache dir.
# shellcheck disable=SC2034  # used by the scripts that source this file
RE_FRIDA_NAME_FILE="$RE_DATA_DIR/frida/server-name"

# The name frida-server is pushed and run under on the device. A fixed
# "frida-server" is trivially spotted by anti-Frida checks that scan the
# process list and /data/local/tmp, so instead we use a random, innocuous name,
# persisted in RE_FRIDA_NAME_FILE so every command (and later shells) agree on
# it, and rotated by 'frida-server --refresh'. Pin one by exporting
# RE_FRIDA_NAME yourself; android/env.sh exports the persisted value so you can
# read it, marking it _RE_FRIDA_NAME_AUTO so that auto-export doesn't count as a
# pin here and a rotation still takes effect in the same shell.
re_frida_name() {
    if [ -n "${RE_FRIDA_NAME:-}" ] && [ -z "${_RE_FRIDA_NAME_AUTO:-}" ]; then
        printf '%s\n' "$RE_FRIDA_NAME"; return 0
    fi
    [ -s "$RE_FRIDA_NAME_FILE" ] || re_frida_name_reset >/dev/null || return 1
    cat "$RE_FRIDA_NAME_FILE"
}

# Generate, persist and print a fresh random name. Used on first use and, to
# rotate, by 'frida-server --refresh'.
re_frida_name_reset() {
    local NAME
    NAME=$(re_rand_token) || return 1
    mkdir -p "$(dirname -- "$RE_FRIDA_NAME_FILE")" || return 1
    printf '%s\n' "$NAME" >"$RE_FRIDA_NAME_FILE" || return 1
    printf '%s\n' "$NAME"
}

# Signing options of the commands that re-sign an APK: -k/-p/-a set these
# (use re_sign_opt in the option loop), the defaults mean the debug keystore.
# shellcheck disable=SC2034  # used by the scripts that source this file
KEYSTORE="" KS_PASS="android" KS_ALIAS="androiddebugkey" RE_SIGN_GIVEN=""

# Usage: -k|--keystore|-p|--ks-pass|-a|--alias) re_need_arg "$1" "$#"; re_sign_opt "$1" "$2"; shift 2 ;;
re_sign_opt() {
    RE_SIGN_GIVEN=1
    case "$1" in
        -k|--keystore) KEYSTORE="$2" ;;
        -p|--ks-pass)  KS_PASS="$2" ;;
        -a|--alias)    KS_ALIAS="$2" ;;
    esac
}

# Dies if -k named a keystore that doesn't exist
re_check_keystore() {
    [ -z "$KEYSTORE" ] || [ -f "$KEYSTORE" ] || re_die "keystore not found: $KEYSTORE"
}

# Serials of connected, authorised devices. --physical skips emulators.
re_adb_devices() {
    if [ "${1:-}" = "--physical" ]; then
        adb devices | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ { print $1 }'
    else
        adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'
    fi
}

# Prints the directory of the AVD called NAME (honours a custom path= in its
# .ini). Fails if there is no such AVD.
re_avd_dir() {
    local AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}" DIR
    [ -f "$AVD_HOME/$1.ini" ] || return 1
    DIR=$(sed -n 's/^path=//p' "$AVD_HOME/$1.ini" 2>/dev/null)
    echo "${DIR:-$AVD_HOME/$1.avd}"
}

# Prints "SERIAL AVD_NAME" for every running emulator adb knows about.
re_running_emulators() {
    local S NAME
    for S in $(re_adb_devices | grep '^emulator-'); do
        NAME=$(adb -s "$S" emu avd name 2>/dev/null | head -n 1 | tr -d '\r')
        echo "$S ${NAME:-?}"
    done
}

# Prints the serial of the running emulator for the AVD called NAME.
re_emulator_serial() {
    re_running_emulators | awk -v n="$1" '$2 == n { print $1; exit }'
}

# Prints the "SERIAL AVD_NAME" line of the running emulator that ID names,
# whichever way round it is: an 'emulator-NNNN' serial or an AVD name (a
# serial wins, so an AVD named after someone else's serial can't shadow it).
# --read-only lets two emulators run one AVD, and then the name is ambiguous:
# the first is taken and the caller is warned to use a serial instead.
# Prints nothing and fails when no running emulator matches.
re_match_emulator() {
    local LINE MATCHES
    LINE=$(re_running_emulators | awk -v id="$1" '$1 == id { print; exit }')
    if [ -z "$LINE" ]; then
        MATCHES=$(re_running_emulators | awk -v id="$1" '$2 == id')
        LINE=$(head -n 1 <<<"$MATCHES")
        if [ -n "$LINE" ] && [ "$(wc -l <<<"$MATCHES")" -gt 1 ]; then
            re_warn "several emulators run the AVD '$1', taking ${LINE%% *}. Name one by its serial to be sure:"
            sed 's/^/  /' <<<"$MATCHES" >&2
        fi
    fi
    [ -n "$LINE" ] || return 1
    echo "$LINE"
}

# Succeeds once the device SERIAL has finished booting.
re_boot_completed() {
    [ "$(adb -s "$1" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]
}

# Prints the host:port a device uses as its proxy to reach PORT on this
# machine (default: $RE_PROXY_PORT). Emulators reach it at 10.0.2.2; anything
# else gets the port tunnelled back over 'adb reverse' (set up here).
# Usage: re_proxy_address SERIAL [PORT]
re_proxy_address() {
    local PORT="${2:-$RE_PROXY_PORT}"
    case "$1" in
        emulator-*) echo "10.0.2.2:$PORT" ;;
        *)
            adb -s "$1" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null || return 1
            echo "127.0.0.1:$PORT" ;;
    esac
}

# Clears the global HTTP proxy on SERIAL and, for a physical device, the adb
# reverse tunnel that proxy goes through. Only that tunnel: others (another
# tool's, on another port or with no proxy set) are left alone. PROXY is the
# current proxy, when the caller already has it (re_device_proxy).
# Usage: re_proxy_off SERIAL [PROXY]
re_proxy_off() {
    local P="${2-$(re_device_proxy "$1")}"
    adb -s "$1" shell settings put global http_proxy :0 || return 1
    case "$1:$P" in
        emulator-*) ;;
        *:127.0.0.1:*|*:localhost:*) adb -s "$1" reverse --remove "tcp:${P##*:}" >/dev/null 2>&1 ;;
    esac
    return 0
}

# Prints the global HTTP proxy set on SERIAL, or nothing when there is none.
re_device_proxy() {
    local P
    P=$(adb -s "$1" shell settings get global http_proxy 2>/dev/null | tr -d '\r')
    case "$P" in ""|null|:0) ;; *) echo "$P" ;; esac
}

# Succeeds if SERIAL proxies to its own localhost (PROXY) without the adb
# reverse tunnel that makes it reach this machine: it then has no network.
# Usage: re_proxy_tunnel_missing SERIAL PROXY
re_proxy_tunnel_missing() {
    case "$1:$2" in
        emulator-*) return 1 ;;
        *:127.0.0.1:*|*:localhost:*) ! adb -s "$1" reverse --list 2>/dev/null | grep -q "tcp:${2##*:}" ;;
        *) return 1 ;;
    esac
}

# Loads or saves snapshot NAME on the running emulator SERIAL through its
# console. On failure, prints the emulator's reply to stderr.
# Usage: re_emu_snapshot SERIAL load|save NAME
re_emu_snapshot() {
    local OUT
    OUT=$(adb -s "$1" emu avd snapshot "$2" "$3" 2>&1 | tr -d '\r')
    grep -q '^OK' <<<"$OUT" && return 0
    sed 's/^/  /' <<<"$OUT" >&2
    return 1
}

# Sets the array RE_APKS to the APK files under DIR (any depth).
re_find_apks() {
    RE_APKS=()
    while IFS= read -r -d '' REPLY; do
        RE_APKS+=("$REPLY")
    done < <(find "$1" -type f -name '*.apk' -print0)
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
    local CALLER="$1" SERIAL="${2:-}" KIND="device" CMD LINE
    CMD=${CALLER%% *}   # the command's name, for the error messages
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
    # A serial given by hand has to match the filter too, or an emulator ends
    # up being treated (and reported) as a phone
    if [ -n "$FILTER" ]; then
        case "$SERIAL" in
            emulator-*)
                echo "Error: $SERIAL is an emulator, and $CMD only works on a physical device." >&2
                return 1 ;;
        esac
    fi
    if [ "$(adb -s "$SERIAL" get-state 2>/dev/null)" != "device" ]; then
        # Nothing connected answers to it, so it may be an AVD name: where a
        # serial is wanted that names one device just as well, as long as an
        # emulator is running it. A physical device is never an AVD.
        if [ -n "$FILTER" ]; then
            if re_avd_dir "$SERIAL" >/dev/null; then
                echo "Error: '$SERIAL' is an AVD name, and $CMD only works on a physical device." >&2
                return 1
            fi
        elif LINE=$(re_match_emulator "$SERIAL"); then
            echo "Note: '$SERIAL' is an AVD name, taking the emulator running it (${LINE%% *})." >&2
            SERIAL=${LINE%% *}
        elif re_avd_dir "$SERIAL" >/dev/null; then
            echo "Error: '$SERIAL' is an AVD name, and no emulator is running it." >&2
            echo "Start it with: launch-emulator $SERIAL" >&2
            return 1
        fi
        if [ "$(adb -s "$SERIAL" get-state 2>/dev/null)" != "device" ]; then
            echo "Error: device '$SERIAL' is not connected or not authorised (see 'adb devices')." >&2
            return 1
        fi
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

# Prints how to run commands as root on SERIAL (re_root_mode, trying 'adb
# root' first), or exits saying what's needed.
# Usage: ROOT=$(re_require_root SERIAL) || exit 1
re_require_root() {
    re_root_mode --adb-root "$1" \
        || re_die "no root on $1 (needs an emulator with a Google APIs image, a userdebug build, or su via Magisk/KernelSU)."
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

# Prints the Python that has Frida's bindings: the one the frida CLI runs on
# (pipx keeps it in a venv of its own), else python3. Fails if neither can
# 'import frida'.
re_frida_python() {
    local PY
    PY=$(head -n 1 "$(command -v frida 2>/dev/null)" 2>/dev/null | sed -n 's/^#![[:space:]]*//p')
    # shellcheck disable=SC2086  # "#!/usr/bin/env python3": its words, not the line
    set -- $PY
    [ "${1##*/}" != env ] || shift
    PY=${1:-}
    case "${PY##*/}" in python*) ;; *) PY=python3 ;; esac
    "$PY" -I -c 'import frida' >/dev/null 2>&1 || return 1
    echo "$PY"
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

# Exits unless NAME is a valid package name (it ends up in device shell commands).
re_check_package_name() {
    case "$1" in
        ""|*[!A-Za-z0-9._]*|.*|*.) re_die "not a valid package name: $1" ;;
    esac
}

# Pulls PACKAGE's base APK from SERIAL into the file DEST, and sets RE_SPLITS
# to the names of its split APKs (e.g. "config.arm64_v8a config.xxhdpi").
# Usage: re_pull_base_apk SERIAL PACKAGE DEST
re_pull_base_apk() {
    local SERIAL="$1" PKG="$2" DEST="$3" LINE PATHS BASE="" FIRST="" NAME
    RE_SPLITS=""
    PATHS=$(adb -s "$SERIAL" shell pm path "$PKG" 2>/dev/null | tr -d '\r')
    [ -n "$PATHS" ] || re_require_package "$SERIAL" "$PKG"   # exits, suggesting names
    while IFS= read -r LINE; do
        LINE=${LINE#package:}
        case "$LINE" in
            */base.apk) BASE="$LINE" ;;
            *.apk)
                NAME=${LINE##*/}; NAME=${NAME%.apk}; NAME=${NAME#split_}
                RE_SPLITS="${RE_SPLITS:+$RE_SPLITS }$NAME"
                [ -n "$FIRST" ] || FIRST="$LINE" ;;
        esac
    done <<<"$PATHS"
    BASE=${BASE:-$FIRST}
    [ -n "$BASE" ] || re_die "could not find the APK of $PKG."
    adb -s "$SERIAL" pull "$BASE" "$DEST" >/dev/null 2>&1 && [ -s "$DEST" ] \
        || re_die "could not pull $BASE."
}

# Sets RE_AAPT2 to the aapt2 to use (PATH, or the SDK build-tools), or exits.
re_require_aapt2() {
    RE_AAPT2=$(re_find_build_tool aapt2) \
        || re_die "'aapt2' not found (PATH or \$ANDROID_HOME/build-tools). Install the SDK build-tools."
}

# Reads the binary XML file FILE (default: the manifest) of APK, as aapt2's
# indented tree. Needs RE_AAPT2 (re_require_aapt2).
# Usage: re_apk_xmltree APK [FILE]
re_apk_xmltree() {
    "$RE_AAPT2" dump xmltree --file "${2:-AndroidManifest.xml}" "$1" 2>/dev/null
}

# Names the framework or game engine an APK is built with, from two kinds of
# signal fed on stdin, one per line: the APK's entry paths (lib/*.so, assets/*)
# and the fully-qualified class names in its manifest (activities, services,
# providers). The manifest classes are the strongest signal -- org.cocos2dx.*,
# com.unity3d.player.*, io.flutter.* and the like give the engine away even when
# the native library has been renamed (libgame.so) or lives in a config split,
# because the manifest is always in the base APK. Prints one tab-separated line
# for the first engine matched, else nothing (a plain Java/Kotlin app):
#   ENGINE \t EVIDENCE \t CODE \t HOW-TO-GET-AT-THE-CODE
# EVIDENCE is the actual matching lines (up to 3), so the call is verifiable.
# Order matters: the more specific engines (Unity IL2CPP before Mono) come
# first, and the first match wins. A class marker is written (^|[/.])pkg[/.]
# so it matches both a path (a/b/C) and a class name (a.b.C).
re_apk_framework() {
    local _sig
    _sig=$(cat)
    # PATTERN ENGINE CODE HOW: prints the record and succeeds if PATTERN matches
    _re_fw() {
        local ev
        ev=$(grep -Eh -- "$1" <<<"$_sig" | head -3 | tr '\n' ' ' | sed 's/ *$//')
        [ -n "$ev" ] || return 1
        printf '%s\t%s\t%s\t%s\n' "$2" "$ev" "$3" "$4"
    }
    _re_fw '(^|/)libflutter\.so$|^assets/flutter_assets/|(^|[/.])io[/.]flutter[/.]' \
        "Flutter (Dart)" \
        "Dart, compiled to native in lib/*/libapp.so (not in the dex)" \
        "blutter; reFlutter to re-pack it trusting your proxy CA" && return
    _re_fw '^assets/index\.android\.bundle$|(^|/)libhermes\.so$|(^|[/.])com[/.]facebook[/.]react[/.]' \
        "React Native" \
        "JavaScript in assets/index.android.bundle (Hermes bytecode when libhermes is present)" \
        "de-minify the JS; hermes-dec or hbctool for Hermes bytecode" && return
    _re_fw '(^|/)libil2cpp\.so$|(^|/)global-metadata\.dat$' \
        "Unity (IL2CPP)" \
        "C#, compiled to native in libil2cpp.so, with type names in global-metadata.dat" \
        "Il2CppDumper or Il2CppInspector (needs the .so and the .dat)" && return
    _re_fw '(^|/)libunity\.so$|^assets/bin/Data/Managed/[^/]+\.dll$' \
        "Unity (Mono)" \
        ".NET assemblies in assets/bin/Data/Managed/*.dll" \
        "dnSpy or ILSpy" && return
    _re_fw '(^|[/.])com[/.]unity3d[/.]player[/.]' \
        "Unity" \
        "C# game; whether it's IL2CPP or Mono isn't visible from the manifest alone" \
        "look for libil2cpp.so (IL2CPP) or assets/bin/Data/Managed/*.dll (Mono)" && return
    _re_fw '(^|/)lib(monodroid|monosgen|xamarin)[^/]*\.so$|^assemblies/|^assemblies\.blob$|(^|[/.])mono[/.]MonoRuntimeProvider' \
        "Xamarin / .NET for Android" \
        ".NET assemblies in assemblies/ (or packed in assemblies.blob)" \
        "dnSpy or ILSpy; xamarin-decompress for a compressed blob" && return
    _re_fw '(^|/)libcocos[^/]*\.so$|^assets/jsb-adapter/|^assets/(src/|project\.json$|main\.js$)|(^|[/.])org[/.]cocos2dx[/.]' \
        "Cocos2d-x / Cocos Creator" \
        "scripts in assets/ (JavaScript or Lua), often XXTEA-encrypted" \
        "read the scripts; if encrypted, crypto-find the .so for the XXTEA key" && return
    _re_fw '(^|/)lib(Unreal|UE[0-9])[^/]*\.so$|(^|[/.])com[/.]epicgames[/.]' \
        "Unreal Engine" \
        "C++ native; game assets packed in .pak files (often in the OBB)" \
        "Unreal .pak tools such as FModel" && return
    _re_fw '(^|/)libgodot[^/]*\.so$|(^|/)[^/]+\.pck$|(^|[/.])(org[/.]godotengine|com[/.]godot)[/.]' \
        "Godot" \
        "scenes and GDScript packed in the .pck" \
        "Godot RE tools such as gdsdecomp" && return
    _re_fw '(^|/)libNativeScript[^/]*\.so$|^assets/app/|(^|[/.])com[/.]tns[/.]' \
        "NativeScript" \
        "JavaScript in assets/app/" \
        "read the JS in assets/app/" && return
    _re_fw '(^|/)libQt[0-9][^/]*\.so$|(^|[/.])org[/.]qtproject[/.]' \
        "Qt" \
        "native C++; QML may be in assets/ or embedded as a resource" \
        "bin-triage the .so; look for QML in assets/" && return
    _re_fw '(^|/)libpython[^/]*\.so$|^assets/chaquopy/|(^|[/.])org[/.](kivy|beeware)[/.]' \
        "Python" \
        "Python bytecode in assets/ (Kivy/BeeWare, or Chaquopy in assets/chaquopy/)" \
        "decompile the .pyc (decompyle3)" && return
    _re_fw '^assets/capacitor\.config\.json$|^assets/public/index\.html$|(^|[/.])com[/.]getcapacitor[/.]' \
        "Capacitor" \
        "web app in assets/public/" \
        "read the web code in assets/public/" && return
    _re_fw '^assets/www/cordova(_plugins)?\.js$|^assets/www/index\.html$|(^|[/.])org[/.]apache[/.]cordova' \
        "Cordova / PhoneGap" \
        "web app in assets/www/" \
        "read the web code in assets/www/" && return
    return 1
}

# awk functions for aapt2's trees and the records below, put in front of an
# awk program: awk "$RE_AWK_LIB"'...'
#   xt(line)   parses a line of an aapt2 tree. Sets XT to E (element), A
#              (attribute), T (text) or "" (anything else), XI to its
#              indentation, XN to an element's name, XK and XV to an
#              attribute's name (without namespace) and value (without
#              quotes), XV to a text's value.
#   bool(v)    true or false for aapt2's ways of writing a boolean, else v
#   short(n)   .Name for a class in the package pkg (an awk variable)
read -r -d '' RE_AWK_LIB <<'AWK' || true
function xt(line,   s, eq) {
    match(line, /^ */); XI = RLENGTH; s = substr(line, XI + 1)
    XT = ""; XN = XK = XV = ""
    if (s ~ /^E: /) { XT = "E"; XN = substr(s, 4); sub(/ .*/, "", XN) }
    else if (s ~ /^A: /) {
        s = substr(s, 4); eq = index(s, "=")
        if (!eq) return
        XT = "A"; XK = substr(s, 1, eq - 1); XV = substr(s, eq + 1)
        sub(/\(0x[0-9a-fA-F]+\)$/, "", XK); sub(/.*:/, "", XK)
        if (XV ~ /^"/) {
            if (match(XV, /" \(Raw: /)) XV = substr(XV, 2, RSTART - 2)
            else { XV = substr(XV, 2); sub(/"$/, "", XV) }
        } else sub(/ .*/, "", XV)
    } else if (s ~ /^T: /) { XT = "T"; XV = substr(s, 4); gsub(/^'|'$/, "", XV) }
}
function bool(v) {
    if (v == "true" || v == "0xffffffff" || v == "-1") return "true"
    if (v == "false" || v == "0x00000000" || v == "0") return "false"
    return v
}
function short(n) { return (pkg != "" && index(n, pkg ".") == 1) ? substr(n, length(pkg) + 1) : n }
AWK

# Turns the manifest tree (re_apk_xmltree, on stdin) into '|'-separated
# records, one per line:
#   manifest|PACKAGE|VERSION_NAME|VERSION_CODE|MIN_SDK|TARGET_SDK|SHARED_UID
#   application|DEBUGGABLE|ALLOW_BACKUP|USES_CLEARTEXT|NETWORK_SECURITY_CONFIG|TEST_ONLY
#   uses-permission|NAME
#   permission|NAME|PROTECTION_LEVEL          (permissions the app declares)
#   component|N|TYPE|NAME|EXPORTED|PERMISSION|READ_PERMISSION|WRITE_PERMISSION|
#             AUTHORITIES|ACTIONS|LINKS|LAUNCHER|TARGET|EXPLICIT
# Booleans are true/false (empty when the attribute is absent). EXPORTED is
# yes, no or ? (a resource reference), applying Android's defaults when the
# attribute is absent: with an intent filter for activities, services and
# receivers; on API 16 and lower for providers. EXPLICIT says whether the
# manifest sets it. ACTIONS and LINKS are space-separated; LINKS are the URIs
# its intent filters accept (scheme://host/path, '*' ending a prefix), for an
# activity only from filters with the DEFAULT category, as links need. N is
# the component's position in the manifest, from 1.
re_manifest_records() {
    awk "$RE_AWK_LIB"'
        function clean(v) { gsub(/\|/, "%7C", v); gsub(/ /, "%20", v); return v }
        function fullname(n) {
            if (n ~ /^\./) return pkg n
            if (n != "" && n !~ /\./) return pkg "." n
            return n
        }
        function add(list, v) { return list == "" ? v : list " " v }
        # Combines the <data> elements of the intent filter that just ended
        function flush_filter(   i, j, k, l, n) {
            n = 0
            for (i = 1; i <= ns; i++) {
                if (!nh) { l = sch[i] ":"; links[comp] = add(links[comp], clean(l)); continue }
                for (j = 1; j <= nh; j++) {
                    if (!np) { l = sch[i] "://" hst[j]; links[comp] = add(links[comp], clean(l)); continue }
                    for (k = 1; k <= np; k++) {
                        if (++n > 8) return
                        l = sch[i] "://" hst[j] pth[k]
                        links[comp] = add(links[comp], clean(l))
                    }
                }
            }
            if (!ns) for (i = 1; i <= nm; i++) links[comp] = add(links[comp], clean("type:" mim[i]))
        }
        function open_el(name) {
            if (comp == 0 && (name == "activity" || name == "activity-alias" || name == "service" \
                    || name == "receiver" || name == "provider") && EL[d - 1] == "application") {
                comp = ++nc; cdepth = d; ctype[comp] = name
            } else if (comp && name == "intent-filter") {
                hasfilter[comp] = 1; fdepth = d; ns = nh = np = nm = 0; fdefault = 0
            }
        }
        function close_el(i) {
            # An activity is only opened by an implicit intent (a link) if the
            # filter has the DEFAULT category
            if (comp && i == fdepth) { if (fdefault || ctype[comp] !~ /^activity/) flush_filter(); fdepth = 0 }
            if (comp && i == cdepth) comp = 0
        }
        function on_attr(el, k, v) {
            if (el == "manifest") {
                if (k == "package") pkg = v
                else if (k == "versionName") vname = v
                else if (k == "versionCode") vcode = v
                else if (k == "sharedUserId") suid = v
            } else if (el == "uses-sdk") {
                if (k == "minSdkVersion") minsdk = v
                else if (k == "targetSdkVersion") target = v
            } else if (el ~ /^uses-permission/ && k == "name") {
                uperm[++nu] = v
            } else if (el == "permission" && d == pdepth) {
                if (k == "name") pname[np_] = v
                else if (k == "protectionLevel") plevel[np_] = v
            } else if (el == "application") {
                if (k ~ /^(debuggable|allowBackup|usesCleartextTraffic|testOnly)$/) app[k] = bool(v)
                else if (k == "networkSecurityConfig") app[k] = v
            } else if (comp && d == cdepth) {
                if (k == "exported") cexp[comp] = bool(v)
                else if (k ~ /^(name|permission|readPermission|writePermission|authorities|targetActivity)$/) cattr[comp, k] = v
            } else if (comp && fdepth) {
                if (el == "action" && k == "name") actions[comp] = add(actions[comp], v)
                else if (el == "category" && k == "name" && v == "android.intent.category.LAUNCHER") launcher[comp] = 1
                else if (el == "category" && k == "name" && v == "android.intent.category.DEFAULT") fdefault = 1
                else if (el == "data") {
                    if (k == "scheme") sch[++ns] = v
                    else if (k == "host") hst[++nh] = v
                    else if (k == "port" && nh) hst[nh] = hst[nh] ":" v
                    else if (k == "path" || k == "pathPattern" || k == "pathAdvancedPattern") pth[++np] = v
                    else if (k == "pathPrefix") pth[++np] = v "*"
                    else if (k == "pathSuffix") pth[++np] = "*" v
                    else if (k == "mimeType") mim[++nm] = v
                }
            }
        }
        {
            xt($0)
            if (XT == "E") {
                while (d > 0 && IND[d] >= XI) { close_el(d); d-- }
                d++; IND[d] = XI; EL[d] = XN
                if (XN == "permission") { np_++; pdepth = d }
                open_el(XN)
            } else if (XT == "A" && d > 0) on_attr(EL[d], XK, XV)
        }
        END {
            while (d > 0) { close_el(d); d-- }
            if (minsdk == "") minsdk = 1
            if (target == "") target = minsdk
            print "manifest|" pkg "|" vname "|" vcode "|" minsdk "|" target "|" suid
            print "application|" app["debuggable"] "|" app["allowBackup"] "|" app["usesCleartextTraffic"] "|" app["networkSecurityConfig"] "|" app["testOnly"]
            for (i = 1; i <= nu; i++) print "uses-permission|" uperm[i]
            for (i = 1; i <= np_; i++) if (pname[i] != "") print "permission|" pname[i] "|" plevel[i]
            for (i = 1; i <= nc; i++) {
                e = cexp[i]
                if (e == "true") ex = "yes"
                else if (e == "false") ex = "no"
                else if (e != "") ex = "?"
                else if (ctype[i] == "provider") ex = (minsdk + 0 <= 16 || target + 0 <= 16) ? "yes" : "no"
                else ex = hasfilter[i] ? "yes" : "no"
                print "component|" i "|" ctype[i] "|" fullname(cattr[i, "name"]) "|" ex "|" cattr[i, "permission"] "|" \
                    cattr[i, "readPermission"] "|" cattr[i, "writePermission"] "|" cattr[i, "authorities"] "|" \
                    actions[i] "|" links[i] "|" (launcher[i] ? "launcher" : "") "|" fullname(cattr[i, "targetActivity"]) "|" \
                    (e != "" ? "explicit" : "")
            }
        }'
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
            re_warn "zipalign failed, signing unaligned APK."
        fi
    else
        re_warn "'zipalign' not found, skipping alignment."
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
        re_warn "apksigner verify reported problems."
    fi
}

# Converts CERT (PEM or DER; default: $RE_PROXY_CERT) into the
# <subject_hash_old>.0 file Android expects, inside OUT_DIR. Sets RE_CERT_HASH
# and RE_CERT_FILE.
# Usage: re_prepare_cert OUT_DIR [CERT]
re_prepare_cert() {
    local OUT_DIR="$1" CERT="${2:-$RE_PROXY_CERT}" FORM
    if [ -n "${2:-}" ]; then
        [ -f "$CERT" ] || re_die "certificate not found: $CERT"
    else
        re_require_proxy_cert
    fi
    re_require openssl
    FORM=$(re_cert_form "$CERT") || re_die "$CERT is not a PEM or DER X.509 certificate."
    RE_CERT_HASH=$(openssl x509 -inform "$FORM" -in "$CERT" -noout -subject_hash_old)
    RE_CERT_FILE="$OUT_DIR/$RE_CERT_HASH.0"
    openssl x509 -inform "$FORM" -in "$CERT" -outform PEM -out "$RE_CERT_FILE" \
        || re_die "could not convert $CERT to PEM."
}

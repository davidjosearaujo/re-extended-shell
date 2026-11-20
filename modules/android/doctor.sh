# shellcheck shell=bash
# re-doctor checks of the Android module. Sourced by core/bin/re-doctor, which
# provides the doc_* helpers. Read-only: never runs su or changes a device.

# shellcheck source=lib.sh
. "$RE_EXT_HOME/modules/android/lib.sh"

doc_section "Android: SDK"
if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
    doc_ok "ANDROID_HOME $(re_tilde "$ANDROID_HOME")"
elif [ -n "${ANDROID_HOME:-}" ]; then
    doc_fail "ANDROID_HOME points to a missing directory: $ANDROID_HOME" "Fix it in local/env.sh."
else
    doc_fail "Android SDK not found" \
        "Install it with Android Studio, or set ANDROID_HOME in local/env.sh (then open a new shell)."
fi
if doc_tool required adb "every Android command" "Install the SDK's platform-tools."; then
    doc_info "$(adb version 2>/dev/null | head -n 1)"
fi
doc_tool optional emulator "launch-emulator, kill-emulator, reset-emulator" "Install the SDK's emulator package." || true
if [ "$RE_OS" = Linux ]; then
    if [ ! -e /dev/kvm ]; then
        doc_warn "/dev/kvm missing: emulators run without acceleration (or not at all), androidcontainer can't run" \
            "Enable virtualisation (VT-x/AMD-V) in the firmware and load the kvm module."
    elif [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
        doc_warn "No access to /dev/kvm" "Add yourself to its group: sudo usermod -aG kvm \$USER (then log in again)."
    else
        doc_ok "/dev/kvm accessible"
    fi
fi
for TOOL in aapt2 apksigner zipalign; do
    case "$TOOL" in
        aapt2)     USERS="apk-info, app-intent" ;;
        apksigner) USERS="xapk-merger, apk-pull --merge, apk-patch, apk-info (signature)" ;;
        *)         USERS="xapk-merger, apk-pull --merge, apk-patch" ;;
    esac
    if P=$(re_find_build_tool "$TOOL"); then
        doc_ok "$TOOL ${RE_C_DIM}$(re_tilde "$P")${RE_C_OFF}"
    else
        doc_warn "$TOOL not found, needed by $USERS" \
            "Install the SDK build-tools (Android Studio's SDK Manager, or sdkmanager 'build-tools;<version>')."
    fi
done
doc_tool optional java "xapk-merger (APKEditor), apk-patch, apk-decompile (apktool, jadx)" "Install a JDK, or set JAVA_HOME in local/env.sh (then open a new shell)." || true
doc_tool optional keytool "signing with a new debug keystore (comes with Java)" || true

doc_section "Android: tools"
doc_tool optional unzip "xapk-installer, xapk-merger, apk-info" || true
doc_tool optional sqlite3 "app-data --diff (database changes)" "It comes with the SDK platform-tools, or your package manager's sqlite3." || true
if [ -n "${APKEDITOR_JAR:-}" ]; then
    if [ -f "$APKEDITOR_JAR" ]; then doc_ok "APKEditor $(re_tilde "$APKEDITOR_JAR") (APKEDITOR_JAR)"
    else doc_warn "APKEDITOR_JAR points to a missing file: $APKEDITOR_JAR"; fi
elif command -v apkeditor >/dev/null 2>&1; then
    doc_ok "apkeditor ${RE_C_DIM}$(command -v apkeditor)${RE_C_OFF}"
elif [ -f "$RE_APKEDITOR_DL" ]; then
    APKEDITOR_VERSION=$(cat "$RE_APKEDITOR_DL.version" 2>/dev/null)
    doc_ok "APKEditor ${APKEDITOR_VERSION:+$APKEDITOR_VERSION }${RE_C_DIM}$(re_tilde "$RE_APKEDITOR_DL")${RE_C_OFF}"
    doc_info "Update it to the latest release with: xapk-merger --provision"
elif [ -f "$HOME/.local/share/apkeditor/APKEditor.jar" ]; then
    doc_ok "APKEditor ~/.local/share/apkeditor/APKEditor.jar (xapk-merger moves it on next use)"
else
    doc_info "APKEditor not downloaded yet (xapk-merger fetches it on first use, or now with: xapk-merger --provision)"
fi
if doc_tool optional apktool "apk-decompile, apk-patch" "https://apktool.org"; then
    APKTOOL_VERSION=$(apktool --version 2>/dev/null | head -n 1)
    if re_version_lt "$APKTOOL_VERSION" 2.9; then
        doc_warn "apktool $APKTOOL_VERSION is too old to rebuild most current apps (apk-patch)" \
            "Install the latest from https://apktool.org (distribution packages are often years behind)."
    else
        doc_info "apktool $APKTOOL_VERSION"
    fi
fi
if re_tool_cmd "${JADX:-jadx}"; then
    doc_ok "jadx ${RE_C_DIM}${JADX:-$(command -v jadx)}${RE_C_OFF}"
else
    doc_warn "jadx not found, needed by apk-decompile" \
        "No 'apt' package: install via brew/flatpak/a downloaded bin, then set JADX to its command if it isn't 'jadx' on PATH (https://github.com/skylot/jadx)."
fi

if doc_tool optional frida "frida-server, app-memdump" "pip install frida-tools (or pipx install frida-tools)"; then
    FRIDA_VERSION=$(frida --version 2>/dev/null | tr -d '\r')
    CACHED=""
    for F in "$RE_DATA_DIR/frida/frida-server-$FRIDA_VERSION-android-"*; do
        [ -f "$F" ] && CACHED="$CACHED ${F##*-android-}"
    done
    if [ -n "$CACHED" ]; then
        doc_info "Frida $FRIDA_VERSION, frida-server cached for:$CACHED"
    else
        doc_info "Frida $FRIDA_VERSION (frida-server downloads its matching build on first use)"
    fi
    if ! command -v xz >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
        doc_warn "Neither xz nor python3 found, frida-server can't unpack its download"
    fi
    if PY=$(re_frida_python); then
        doc_info "Frida's Python bindings: $(re_tilde "$PY")"
    else
        doc_warn "Frida's Python bindings can't be imported, app-memdump needs them" "pipx install frida-tools"
    fi
fi
doc_tool optional scrcpy "launch-emulator -d (screen mirroring)" "https://github.com/Genymobile/scrcpy" || true
if P=$(re_find_gui_tool wireshark Wireshark); then
    doc_ok "wireshark ${RE_C_DIM}$P${RE_C_OFF}"
else
    doc_warn "wireshark not found, needed by launch-emulator-wireshark" "https://www.wireshark.org"
fi
if [ "$RE_OS" = Linux ]; then
    ENGINE="${RE_CONTAINER_ENGINE:-}"
    if [ -z "$ENGINE" ]; then
        command -v podman >/dev/null 2>&1 && ENGINE=podman || ENGINE=docker
    fi
    doc_tool optional "$ENGINE" "androidcontainer" || true
fi

doc_section "Android: AVDs"
AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
FOUND_AVD=""
HOST_ARCH=$(uname -m)
for INI in "$AVD_HOME"/*.ini; do
    [ -f "$INI" ] || continue
    FOUND_AVD=1
    NAME=$(basename "$INI" .ini)
    DIR=$(re_avd_dir "$NAME")
    CONFIG="$DIR/config.ini"
    SYSDIR=$(sed -n 's/^image\.sysdir\.1 *= *//p' "$CONFIG" 2>/dev/null | head -n 1)
    PLAYSTORE=$(sed -n 's/^PlayStore\.enabled *= *//p' "$CONFIG" 2>/dev/null | head -n 1)
    ABI=$(sed -n 's/^abi\.type *= *//p' "$CONFIG" 2>/dev/null | head -n 1)
    # system-images/android-34/google_apis/x86_64/ -> android-34 google_apis
    IMAGE=$(echo "$SYSDIR" | awk -F/ '{ print $2, $3 }')
    DESC="${IMAGE:-unknown image}${ABI:+ $ABI}"
    if [ -d "$DIR/snapshots/$RE_EMULATOR_SNAPSHOT" ]; then
        DESC="$DESC, '$RE_EMULATOR_SNAPSHOT' snapshot saved"
    else
        DESC="$DESC, no '$RE_EMULATOR_SNAPSHOT' snapshot yet"
    fi
    case "$SYSDIR" in
        *playstore*) PLAYSTORE=true ;;
    esac
    if [ "$PLAYSTORE" = true ] || [ "$PLAYSTORE" = yes ]; then
        doc_warn "$NAME: $DESC" "Google Play image: no 'adb root', so no --ca, frida-server or app-data on it. Use a Google APIs image for those."
    elif [ "$RE_OS" = Darwin ] && [ "$HOST_ARCH" = arm64 ] && case "$ABI" in x86*) true ;; *) false ;; esac; then
        doc_warn "$NAME: $DESC" "x86 images don't boot on Apple Silicon, use an arm64-v8a image."
    else
        doc_ok "$NAME: $DESC"
    fi
done
[ -n "$FOUND_AVD" ] || doc_info "No AVDs in $(re_tilde "$AVD_HOME") (create one in Android Studio's Device Manager, with a Google APIs image)"

doc_section "Android: connected devices"
if ! command -v adb >/dev/null 2>&1; then
    doc_info "Skipped (no adb)"
else
    ANY_DEVICE=""
    while read -r SERIAL STATE _; do
        [ -n "$SERIAL" ] || continue
        ANY_DEVICE=1
        case "$STATE" in
            device) ;;
            unauthorized)
                doc_warn "$SERIAL: unauthorised" "Accept the USB debugging prompt on the device."; continue ;;
            *)
                doc_warn "$SERIAL: $STATE"; continue ;;
        esac
        # One adb round trip, one line per value (expanded on the device)
        # shellcheck disable=SC2016
        INFO=$(adb -s "$SERIAL" shell 'echo "$(getprop ro.product.model)"; echo "$(getprop ro.build.version.release)";
            echo "$(getprop ro.build.version.sdk)"; echo "$(getprop ro.product.cpu.abi)"; echo "$(getprop ro.build.type)";
            echo "$(id -u)"; command -v su >/dev/null 2>&1 && echo su || echo; echo "$(settings get global http_proxy)";
            echo "$(pidof frida-server)"; echo "$(cat '"$RE_DEVICE_DIR"'/frida-server.version 2>/dev/null)"' 2>/dev/null | tr -d '\r')
        {
            IFS= read -r MODEL; IFS= read -r RELEASE; IFS= read -r SDK; IFS= read -r DABI; IFS= read -r BUILD
            IFS= read -r UID_; IFS= read -r HAS_SU; IFS= read -r PROXY; IFS= read -r FRIDA_PID; IFS= read -r FRIDA_VER
        } <<<"$INFO"
        if [ "$UID_" = 0 ]; then ROOT="root (adbd)"
        elif [ -n "$HAS_SU" ]; then ROOT="root via su"
        elif [ "$BUILD" = userdebug ] || [ "$BUILD" = eng ]; then ROOT="no root yet ('adb root' should work)"
        else ROOT="no root"; fi
        doc_ok "${MODEL:-unknown} ($SERIAL): Android $RELEASE (API $SDK), $DABI, $BUILD, $ROOT"

        case "$PROXY" in
            ""|null|:0) doc_info "No global HTTP proxy" ;;
            *)
                doc_info "Global HTTP proxy: $PROXY"
                if re_proxy_tunnel_missing "$SERIAL" "$PROXY"; then
                    doc_warn "$SERIAL proxies to $PROXY but has no adb reverse tunnel, so it has no network" \
                        "Run 'device-proxy -s $SERIAL on' to restore it, or 'device-proxy -s $SERIAL off'."
                fi
                ;;
        esac
        if [ -n "$FRIDA_PID" ]; then
            if [ -n "${FRIDA_VERSION:-}" ] && [ -n "$FRIDA_VER" ] && [ "$FRIDA_VER" != "$FRIDA_VERSION" ]; then
                doc_warn "frida-server $FRIDA_VER running, but this machine has Frida $FRIDA_VERSION" \
                    "Run 'frida-server -s $SERIAL' to replace it with the matching version."
            else
                doc_info "frida-server ${FRIDA_VER:+$FRIDA_VER }running"
            fi
        fi
    done < <(adb devices 2>/dev/null | awk 'NR > 1 && NF >= 2 { print $1, $2 }')
    [ -n "$ANY_DEVICE" ] || doc_info "None connected"
fi

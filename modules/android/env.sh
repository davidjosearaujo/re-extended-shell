# Android module: environment (sourced by bash and zsh).
# Loaded right after local/android.sh, so an ANDROID_HOME set there (or in
# local/env.sh) wins over the detection below.

# Android SDK: keep an existing ANDROID_HOME / ANDROID_SDK_ROOT, else look in
# the default Android Studio locations (Linux, macOS)
if [ -z "${ANDROID_HOME:-}" ]; then
    if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
        ANDROID_HOME="$ANDROID_SDK_ROOT"
    elif [ -d "$HOME/Android/Sdk" ]; then
        ANDROID_HOME="$HOME/Android/Sdk"
    elif [ -d "$HOME/Library/Android/sdk" ]; then
        ANDROID_HOME="$HOME/Library/Android/sdk"
    fi
fi
if [ -n "${ANDROID_HOME:-}" ]; then
    export ANDROID_HOME

    # Newest installed NDK, unless one is pinned already
    if [ -z "${ANDROID_NDK_HOME:-}" ] && [ -d "$ANDROID_HOME/ndk" ]; then
        _re_ndk=$(find "$ANDROID_HOME/ndk" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)
        if [ -n "$_re_ndk" ]; then
            export ANDROID_NDK_HOME="$_re_ndk"
        fi
        unset _re_ndk
    fi
fi

# Settings read by the Android commands (defaults shown, override in
# local/android.sh):
#   RE_ZAP_SNAPSHOT=zap-ready                         emulator snapshot name
#   RE_CONTAINER_ENGINE=podman|docker                 for androidcontainer
#   RE_ANDROID_CONTAINER_IMAGE=...                    for androidcontainer
#   APKEDITOR_JAR=/path/to/APKEditor.jar              for xapk-merger
#   JADX="jadx"                                       apk-decompile: jadx command,
#   JADX_GUI="jadx-gui"                                 and the one in its browse hint
#                                                       (jadx has no apt package; may
#                                                       carry args, e.g. "flatpak run ...")
#   RE_FRIDA_UNPIN_REF=main                           frida-server --ssl-unpinning:
#   RE_FRIDA_UNPIN_SCRIPTS="native-tls-hook.js ..."     which HTTP Toolkit scripts to load

# Android: SDK environment and tools (sourced by bash and zsh).
# Loaded after config/paths.sh and local/paths.sh, then local/android.sh.
# Set ANDROID_HOME in local/env.sh to point at a non-default SDK.

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

    # SDK tools
    re_path_append "$ANDROID_HOME/emulator"
    re_path_append "$ANDROID_HOME/cmdline-tools/latest/bin"
    re_path_append "$ANDROID_HOME/platform-tools"
    export PATH
fi

# Settings read by the Android commands in bin/ (defaults shown, override in
# local/android.sh):
#   RE_ZAP_SNAPSHOT=zap-ready                         emulator snapshot name
#   RE_CONTAINER_ENGINE=podman|docker                 for androidcontainer
#   RE_ANDROID_CONTAINER_IMAGE=...                    for androidcontainer
#   APKEDITOR_JAR=/path/to/APKEditor.jar              for xapk-merger

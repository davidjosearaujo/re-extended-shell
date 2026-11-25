# Android module: environment (sourced by bash and zsh).
# Loaded after local/env.sh, so an ANDROID_HOME set there wins over the
# detection below.

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

# frida-server is pushed and run on the device under a random, persisted name
# (see modules/android/lib.sh) rather than the give-away "frida-server", so
# on-device anti-Frida checks can't spot it by name. Export that name so every
# re-* command and you agree on it, and you can read it. A name you set
# yourself is left untouched and pins it; otherwise we expose the persisted one
# and mark it auto, so 'frida-server --refresh' can still rotate it mid-session.
if [ -z "${RE_FRIDA_NAME:-}" ]; then
    _re_fname_file="${RE_DATA_DIR:-$HOME/.local/share/re-extended-shell}/frida/server-name"
    if [ -s "$_re_fname_file" ]; then
        RE_FRIDA_NAME=$(cat "$_re_fname_file")
        export RE_FRIDA_NAME _RE_FRIDA_NAME_AUTO=1
    fi
    unset _re_fname_file
fi

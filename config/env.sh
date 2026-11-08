# Environment variables (sourced by bash and zsh).
# Only fills in what isn't set yet; put your own values in local/env.sh.

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

# Settings read by the commands in bin/ (defaults shown, override in local/env.sh):
#   RE_ZAP_PORT=9090                                  ZAP proxy port on this machine
#   RE_ZAP_CERT="$RE_EXT_HOME/certs/zap_root_ca.cer"  ZAP root CA, PEM or DER
#   RE_ZAP_SNAPSHOT=zap-ready                         emulator snapshot name
#   RE_CONTAINER_ENGINE=podman|docker                 for androidcontainer
#   RE_ANDROID_CONTAINER_IMAGE=...                    for androidcontainer
#   APKEDITOR_JAR=/path/to/APKEditor.jar              for xapk-merger

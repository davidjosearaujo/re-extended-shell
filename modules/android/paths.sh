# Android module: PATH entries (sourced by bash and zsh).
# This module's bin/ is added by the loader.

if [ -n "${ANDROID_HOME:-}" ]; then
    re_path_append "$ANDROID_HOME/emulator"
    re_path_append "$ANDROID_HOME/cmdline-tools/latest/bin"
    re_path_append "$ANDROID_HOME/platform-tools"
fi

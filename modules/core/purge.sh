# shellcheck shell=bash
# Core module: what the commands leave outside the repo, for ./uninstall.
# Sourced by ./uninstall, which provides re_purge.

# Shared download/cache folder (RE_DATA_DIR in lib.sh), e.g. frida-server builds
re_purge "$HOME/.local/share/re-extended-shell" "$HOME/.local/share/re-extended-shell/ (downloads and caches)"

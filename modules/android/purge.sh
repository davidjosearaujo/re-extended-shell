# shellcheck shell=bash
# Android module: what the commands leave outside the repo, for ./uninstall.
# Sourced by ./uninstall, which provides re_purge and PURGE.

re_purge "$HOME/.local/share/apkeditor/APKEditor.jar" "$HOME/.local/share/apkeditor/APKEditor.jar (xapk-merger)"
if [ -n "$PURGE" ]; then rmdir "$HOME/.local/share/apkeditor" 2>/dev/null || true; fi

# The ZAP snapshot of every AVD (saved by launch-emulator)
_re_avd_home="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
_re_snapshot="${RE_ZAP_SNAPSHOT:-zap-ready}"
for _re_ini in "$_re_avd_home"/*.ini; do
    [ -f "$_re_ini" ] || continue
    _re_name=$(basename -- "$_re_ini" .ini)
    _re_dir=$(sed -n 's/^path=//p' "$_re_ini" 2>/dev/null)
    [ -n "$_re_dir" ] || _re_dir="$_re_avd_home/$_re_name.avd"
    [ -d "$_re_dir/snapshots/$_re_snapshot" ] || continue
    # The emulator holds *.lock files in the AVD dir while it runs
    if [ -n "$PURGE" ] && compgen -G "$_re_dir/*.lock" >/dev/null; then
        echo "  Skipped snapshot '$_re_snapshot' of $_re_name: the emulator is running (run: kill-emulator $_re_name)"
        continue
    fi
    re_purge "$_re_dir/snapshots/$_re_snapshot" "snapshot '$_re_snapshot' of AVD $_re_name (launch-emulator)"
done
true

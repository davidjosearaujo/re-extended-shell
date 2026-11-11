# shellcheck shell=bash
# Android module: what the commands leave outside the repo, for ./uninstall.
# Sourced by ./uninstall, which provides re_purge and PURGE.

# The APKEditor download now lives under RE_DATA_DIR (covered by core); this is
# where older versions of xapk-merger put it
re_purge "$HOME/.local/share/apkeditor/APKEditor.jar" "$HOME/.local/share/apkeditor/APKEditor.jar (xapk-merger, old location)"
if [ -n "$PURGE" ]; then rmdir "$HOME/.local/share/apkeditor" 2>/dev/null || true; fi

# The snapshot launch-emulator saves on every AVD, and 'zap-ready', the one
# older versions saved
_re_avd_home="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
for _re_ini in "$_re_avd_home"/*.ini; do
    [ -f "$_re_ini" ] || continue
    _re_name=$(basename -- "$_re_ini" .ini)
    _re_dir=$(sed -n 's/^path=//p' "$_re_ini" 2>/dev/null)
    [ -n "$_re_dir" ] || _re_dir="$_re_avd_home/$_re_name.avd"
    for _re_snapshot in "${RE_EMULATOR_SNAPSHOT:-re-ready}" zap-ready; do
        [ -d "$_re_dir/snapshots/$_re_snapshot" ] || continue
        # The emulator holds *.lock files in the AVD dir while it runs
        if [ -n "$PURGE" ] && compgen -G "$_re_dir/*.lock" >/dev/null; then
            echo "  Skipped snapshot '$_re_snapshot' of $_re_name: the emulator is running (run: kill-emulator $_re_name)"
            continue
        fi
        re_purge "$_re_dir/snapshots/$_re_snapshot" "snapshot '$_re_snapshot' of AVD $_re_name (launch-emulator)"
    done
done
true

# shellcheck shell=bash
# The shell loader and the installer, in a throwaway copy of the repo and HOME.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

COPY="$T_DIR/repo"
mkdir -p "$COPY"
(cd "$REPO" && tar --exclude=.git --exclude=./local --exclude=./certs -cf - .) | (cd "$COPY" && tar -xf -)

# Loading: PATH gets every module's bin, and local/env.sh wins over detection
mkdir -p "$COPY/local"
cat >"$COPY/local/env.sh" <<'SH'
export RE_ZAP_PORT=1234
export ANDROID_HOME="/nonexistent/sdk"
SH
run env -i HOME="$HOME" PATH=/usr/bin:/bin bash -c ". '$COPY/re_extended_shell_main'; echo PORT=\$RE_ZAP_PORT; echo SDK=\$ANDROID_HOME; echo \$PATH"
expect_rc 0 "the loader sources cleanly"
expect_out "PORT=1234" "local/env.sh sets a setting"
expect_out "SDK=/nonexistent/sdk" "...and wins over SDK detection"
for M in core android binary; do
    expect_out "$COPY/modules/$M/bin" "$M/bin is on PATH"
done
run env -i HOME="$HOME" PATH=/usr/bin:/bin bash -c ". '$COPY/re_extended_shell_main'; type reset-emulator bin-triage re-doctor device-proxy | grep -c 'is '"
expect_out "4" "the commands resolve"

# Installing: hooks the rc file once, creates local/ files, never overwrites
rm -rf "$COPY/local"
run bash "$COPY/install" --bash
expect_rc 0 "install runs"
for F in env paths aliases functions completions; do
    [ -f "$COPY/local/$F.sh" ] && pass "install creates local/$F.sh" || fail "install creates local/$F.sh"
done
echo "export MINE=1" >>"$COPY/local/env.sh"
run bash "$COPY/install" --bash
grep -q "MINE=1" "$COPY/local/env.sh" && pass "a second install keeps your local/env.sh" || fail "a second install keeps your local/env.sh"
expect_eq "$(grep -c 're_extended_shell_main' "$HOME/.bashrc")" "1" "the rc hook is there exactly once"
run bash "$COPY/uninstall" --bash
expect_eq "$(grep -c 're_extended_shell_main' "$HOME/.bashrc")" "0" "uninstall removes the hook"
[ -f "$COPY/local/env.sh" ] && pass "...and keeps local/" || fail "...and keeps local/"

done_testing

# shellcheck shell=bash
# Every option that takes a value must fail cleanly without one. Parsers used to
# loop forever when it was the last argument.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset

while read -r CMD OPT; do
    run "$CMD" "$OPT"
    if [ "$RC" = 124 ]; then
        fail "$CMD $OPT without a value" "hung (killed after 30s)"
    elif [ "$RC" != 0 ] && grep -qF -- "$OPT needs a value" <<<"$OUT"; then
        pass "$CMD $OPT without a value is an error"
    else
        fail "$CMD $OPT without a value" "exit code $RC" "output: $OUT"
    fi
done <<'LIST'
xapk-installer -s
xapk-installer -n
xapk-merger -o
xapk-merger -k
xapk-merger -p
xapk-merger -a
xapk-merger -j
launch-emulator-wireshark -s
launch-emulator-wireshark -i
apk-pull -s
applog -s
frida-server -s
frida-server -l
frida-server --ssl-unpinning
apk-pull -o
apk-pull -k
apk-decompile -o
apk-patch -o
apk-patch -k
reset-emulator --snapshot
reset-emulator -s
reset-emulator -n
device-proxy -s
release-device -s
launch-emulator -s
bin-triage -n
bin-triage -l
LIST

# (help layout and unknown options for every command: t_family.sh)
run launch-emulator --wiped TestAvd_A
expect_rc 1 "--wiped is gone (use --clean)"

done_testing

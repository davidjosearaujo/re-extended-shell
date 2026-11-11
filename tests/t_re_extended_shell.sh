# shellcheck shell=bash
# re-extended-shell, in a throwaway copy of the repo (so local/ is ours).
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset

COPY="$T_DIR/repo"
mkdir -p "$COPY"
(cd "$REPO" && tar --exclude=.git --exclude=./local --exclude=./certs -cf - .) | (cd "$COPY" && tar -xf -)
mkdir -p "$COPY/local"
cat >"$COPY/local/env.sh" <<'SH'
export RE_PROXY_PORT=1234
SH
cat >"$COPY/local/aliases.sh" <<'SH'
alias ll='ls -l'
SH
cat >"$COPY/local/functions.sh" <<'SH'
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
SH
mkdir -p "$T_DIR/mybin"
echo "re_path_append '$T_DIR/mybin'" >"$COPY/local/paths.sh"
RES="$COPY/modules/core/bin/re-extended-shell"
unset RE_EXT_HOME

run "$RES" --version
expect_rc 0 "--version"
expect_out "RE Extended Shell " "...names the project"

run "$RES"
expect_rc 0 "no option shows everything"
for S in Modules Commands "Settings (environment variables)" "PATH entries" Aliases Functions "Downloads and caches"; do
    expect_out "$S" "...including $S"
done
expect_out "Not loaded in this shell" "says when this shell hasn't loaded it"

run "$RES" --commands
for F in "$COPY"/modules/*/bin/*; do
    awk -v n="${F##*/}" -v d="$(sed -n '2s/^# //p' "$F")" '$1 == n { sub(/^ *[^ ]+ +/, ""); if ($0 == d) f = 1 } END { exit !f }' <<<"$OUT" \
        && pass "--commands lists ${F##*/} with its summary" || fail "--commands lists ${F##*/} with its summary" "output: $OUT"
done
expect_no_out "Settings" "--commands shows only that section"

run "$RES" --envs
expect_out "RE_PROXY_PORT               1234 (local/env.sh)" "--envs: a value from local/env.sh, aligned"
expect_out "RE_EMULATOR_SNAPSHOT        not set, default: re-ready" "--envs: a default"
RE_EMULATOR_SNAPSHOT=mine run "$RES" --envs
expect_out "RE_EMULATOR_SNAPSHOT        mine (environment)" "--envs: a value from the environment"

run "$RES" -m binary --commands --envs
expect_out "bin-triage" "-m keeps that module"
expect_no_out "launch-emulator" "...and drops the others"
run "$RES" -m nope
expect_rc 1 "-m with an unknown module fails"
expect_out "no module 'nope'" "...and names it"

# --paths agrees with what the loader really adds
run "$RES" --paths
for M in core android binary; do
    expect_out "$COPY/modules/$M/bin" "--paths lists $M/bin"
done
expect_out "local    $T_DIR/mybin" "--paths lists local/paths.sh entries"
LOADED=$(env -i HOME="$HOME" PATH=/usr/bin:/bin bash -c ". '$COPY/re_extended_shell_main'; echo \"\$PATH\"" | tr ':' '\n' | grep -vxE '/usr/bin|/bin')
SHOWN=$(sed -n '/^PATH entries/,/^$/p' <<<"$OUT" | awk 'NF >= 2 && $1 != "PATH" { print $2 }')
expect_eq "$SHOWN" "$LOADED" "--paths lists exactly what the loader adds, in order"

run "$RES" --aliases --functions
expect_out "ll='ls -l'  (local/aliases.sh)" "--aliases reads local/aliases.sh"
expect_out "mkcd()  (local/functions.sh)" "--functions reads local/functions.sh"

mkdir -p "$HOME/.local/share/re-extended-shell/frida"
echo x >"$HOME/.local/share/re-extended-shell/frida/f"
run "$RES" --data
expect_out ".local/share/re-extended-shell/frida" "--data lists the caches"

done_testing

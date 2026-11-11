# shellcheck shell=bash
# app-data: the fake device's staged copy lives in $FAKE_STATE/files/<stage>
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

P=com.example.app
setup() {
    fake_reset; fake_device PHONE123
    STAGE="$FAKE_STATE/files/data/local/tmp/re-ext/app-data"
    mkdir -p "$STAGE/data/shared_prefs" "$STAGE/data/databases" "$STAGE/user_de"
    printf '<map>\n    <string name="auth_token">abc123</string>\n    <int name="launches" value="1" />\n</map>\n' \
        >"$STAGE/data/shared_prefs/prefs.xml"
    echo device >"$STAGE/user_de/state"
}
HAVE_SQLITE=""; command -v sqlite3 >/dev/null 2>&1 && HAVE_SQLITE=1

setup
[ -z "$HAVE_SQLITE" ] || sqlite3 "$STAGE/data/databases/app.db" "CREATE TABLE users(name TEXT); INSERT INTO users VALUES('alice');
    CREATE TABLE tokens(t TEXT); INSERT INTO tokens VALUES('ghp_abcdefghijklmnopqrstuvwxyz0123456789');"
cd "$T_DIR" || exit 1
run app-data $P
expect_rc 0 "pulls the data"
expect_log "-s PHONE123 pull /data/local/tmp/re-ext/app-data" "...from the staging folder"
[ -f "$P-data/data/shared_prefs/prefs.xml" ] && [ -f "$P-data/user_de/state" ] \
    && pass "...into ./<PACKAGE>-data/, one folder per storage" || fail "...into ./<PACKAGE>-data/, one folder per storage" "$(find "$P-data" 2>&1)"
expect_out "data/shared_prefs/prefs.xml" "lists the preferences"
expect_out "auth_token" "flags token-like lines"
if [ -n "$HAVE_SQLITE" ]; then expect_out "data/databases/app.db" "lists the databases"; else skip "lists the databases" "no sqlite3"; fi
expect_log "rm -rf /data/local/tmp/re-ext/app-data" "cleans the staging folder up"
if [ -n "$HAVE_SQLITE" ] && command -v stringx >/dev/null 2>&1; then
    SECRETS=$(sed -n '/Possible secrets/,/^$/p' <<<"$OUT")
    grep -q '^  data/databases/app.db: .*ghp_abcdefghijklmnopqrstuvwxyz0123456789' <<<"$SECRETS" \
        && pass "with stringx: finds a token inside a database" || fail "with stringx: finds a token inside a database" "$SECRETS"
else
    skip "finds a token inside a database" "needs sqlite3 and stringx"
fi
expect_out "Saved to $T_DIR/$P-data/" "says where it went"

run app-data $P
expect_rc 1 "refuses to replace an earlier copy"
expect_out "already exists (use -f" "...and says to use -f"

# --diff: what changed on the device since the first copy
printf '<map>\n    <string name="auth_token">xyz789</string>\n    <int name="launches" value="2" />\n</map>\n' \
    >"$STAGE/data/shared_prefs/prefs.xml"
mkdir -p "$STAGE/data/files"; echo hello >"$STAGE/data/files/new.txt"
rm "$STAGE/user_de/state"
[ -z "$HAVE_SQLITE" ] || sqlite3 "$STAGE/data/databases/app.db" "INSERT INTO users VALUES('bob');"
run app-data --diff "$P-data" -o after $P
expect_rc 0 "--diff pulls a new copy"
[ -d after/data ] && pass "...into -o" || fail "...into -o"
expect_out "~ data/shared_prefs/prefs.xml" "marks a changed file"
expect_out "+ data/files/new.txt" "...an added one"
expect_out "- user_de/state" "...and a removed one"
expect_out '+    <string name="auth_token">xyz789</string>' "shows what changed in a text file"
expect_out '-    <string name="auth_token">abc123</string>' "...old and new lines"
if [ -n "$HAVE_SQLITE" ]; then
    expect_out "data/databases/app.db (database)" "a changed database is dumped"
    expect_out "+INSERT INTO users VALUES('bob');" "...showing the new row"
    expect_no_out "+INSERT INTO users VALUES('alice');" "...not marking the unchanged ones"
else
    skip "a changed database is dumped" "no sqlite3"
fi
[ "$(cat "$P-data/data/shared_prefs/prefs.xml" | grep -c abc123)" = 1 ] \
    && pass "the earlier copy is left as it was" || fail "the earlier copy is left as it was"

# Errors
run app-data --diff after -o after -f $P
expect_out "name the same directory" "--diff and -o can't be the same"
mkdir notacopy
run app-data --diff notacopy $P
expect_out "is not an earlier app-data copy" "--diff checks the folder"
setup
rm -rf "$STAGE"
run app-data -o empty $P
expect_rc 1 "an app without data fails"
expect_out "found no data for $P" "...and says so"

done_testing

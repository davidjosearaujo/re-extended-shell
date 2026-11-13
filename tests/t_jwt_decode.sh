# shellcheck shell=bash
# jwt-decode: the header, the payload, the claims and the times, an expired
# token, alg=none, and verifying an HMAC signature with --secret.
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"
fake_reset

if ! command -v openssl >/dev/null 2>&1; then
    skip "jwt-decode" "openssl not installed"
    done_testing
    exit 0
fi

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
# sign HEADER_B64 PAYLOAD_B64 SECRET: the HS256 signature of that token
sign() { printf '%s' "$1.$2" | openssl dgst -sha256 -mac HMAC -macopt "key:$3" -binary | b64url; }

NOW=$(date -u +%s)
H=$(printf '%s' '{"alg":"HS256","typ":"JWT","kid":"key-1"}' | b64url)
P=$(printf '{"iss":"https://auth.test","sub":"user-42","aud":["api","web"],"iat":%d,"exp":%d}' \
    "$((NOW - 3600))" "$((NOW + 1800))" | b64url)
SIG=$(sign "$H" "$P" hunter2)
TOKEN="$H.$P.$SIG"

run jwt-decode "$TOKEN"
expect_rc 0 "decodes a token"
expect_out "== Header ==" "prints the header"
expect_out "== Payload ==" "prints the payload"
expect_out "HS256" "names the algorithm"
expect_out "key-1" "shows the key id"
expect_out "https://auth.test" "shows the issuer"
expect_out "user-42" "shows the subject"
expect_out "api, web" "shows an audience that is a list"
expect_out "1 hour ago" "says when it was issued, relative to now"
expect_out "in 30 minutes" "...and when it expires"
expect_out "not verified" "says the signature wasn't checked"

run jwt-decode "Bearer $TOKEN"
expect_rc 0 "takes a token with the Bearer prefix"
expect_out "user-42" "...and decodes it the same"

# run() feeds commands /dev/null, so the stdin form is run directly
OUT=$(printf '%s' "$TOKEN" | jwt-decode - 2>&1); RC=$?
expect_rc 0 "reads a token from stdin with -"
expect_out "user-42" "...and decodes it"

# --secret verifies an HMAC signature
run jwt-decode --secret hunter2 "$TOKEN"
expect_rc 0 "--secret with the right key succeeds"
expect_out "verified with that secret" "...and says it verified"

run jwt-decode --secret wrong "$TOKEN"
expect_rc 1 "--secret with the wrong key exits non-zero"
expect_out "does NOT match that secret" "...and says so"

# An expired token
PEXP=$(printf '{"sub":"user-42","exp":%d}' "$((NOW - 7200))" | b64url)
run jwt-decode "$H.$PEXP.$(sign "$H" "$PEXP" hunter2)"
expect_rc 0 "decodes an expired token"
expect_out "2 hours ago), expired" "...marking the exp claim expired"
expect_out "This token has expired" "...and saying what that means"

# A token that isn't usable yet
PNBF=$(printf '{"sub":"x","nbf":%d,"exp":%d}' "$((NOW + 600))" "$((NOW + 1200))" | b64url)
run jwt-decode "$H.$PNBF.sig"
expect_out "not usable yet" "flags a token whose nbf is in the future"

# No exp at all, and nothing signing it
NONE=$(printf '%s' '{"alg":"none"}' | b64url)
PNONE=$(printf '%s' '{"sub":"x"}' | b64url)
run jwt-decode "$NONE.$PNONE."
expect_rc 0 "decodes an unsigned token"
expect_out "no exp claim" "says it never expires on its own"
expect_out "alg=none" "warns that nothing signs it"

# --secret only applies to the HMAC algorithms
RS=$(printf '%s' '{"alg":"RS256"}' | b64url)
run jwt-decode --secret hunter2 "$RS.$PNONE.sig"
expect_rc 1 "--secret on an RS256 token is an error"
expect_out "alg=RS256" "...naming the algorithm it got"

run jwt-decode hello
expect_rc 1 "a value that isn't a token is an error"
expect_out "not a JWT" "...saying so"

run jwt-decode "$(printf '%s' 'not json' | b64url).$P.sig"
expect_rc 1 "a token whose header isn't JSON is an error"
expect_out "isn't JSON" "...saying so"

run jwt-decode "a.b.c.d.e"
expect_rc 1 "a JWE is refused"
expect_out "JWE" "...naming it"

run jwt-decode
expect_rc 1 "no argument is a usage error"
expect_out "missing <token>" "...naming what's missing"

done_testing

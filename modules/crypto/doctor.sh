# shellcheck shell=bash
# re-doctor checks of the crypto module. Sourced by core/bin/re-doctor, which
# provides the doc_* helpers. Read-only.

# shellcheck source=lib.sh
. "$RE_EXT_HOME/modules/crypto/lib.sh"

doc_section "Crypto: tools"
# openssl does cert-info and jwt-decode on its own, and the digests no
# coreutils tool has
doc_tool required openssl "cert-info, jwt-decode, and the SHA-3 and BLAKE2b digests of file-hash" \
    "Install your distribution's 'openssl' package (macOS: brew install openssl)." || true

# Which digests this machine can actually compute, named once
_crypto_have="" _crypto_missing=""
for _pair in $RE_HASH_ALGOS; do
    if re_hash "${_pair%%:*}" /dev/null >/dev/null 2>&1; then
        _crypto_have="$_crypto_have ${_pair#*:}"
    else
        _crypto_missing="$_crypto_missing ${_pair#*:}"
    fi
done
if [ -z "$_crypto_have" ]; then
    doc_fail "no hash tool found, file-hash has nothing to use" \
        "Install coreutils (Linux), or openssl."
elif [ -n "$_crypto_missing" ]; then
    doc_ok "file-hash digests:$_crypto_have"
    doc_info "not available here:$_crypto_missing"
else
    doc_ok "file-hash digests: all of them"
fi
unset _crypto_have _crypto_missing _pair

# Fuzzy hashes are how two versions of a file are compared; neither is required
doc_tool optional ssdeep "file-hash (a fuzzy hash, to compare two versions of a file)" \
    "Install your distribution's 'ssdeep' package." || true
doc_tool optional python3 "file-hash (the CRC-32), jwt-decode (pretty-printing)" || true
command -v python3 >/dev/null 2>&1 \
    || doc_tool optional jq "jwt-decode (pretty-printing, as python3 isn't there)" || true

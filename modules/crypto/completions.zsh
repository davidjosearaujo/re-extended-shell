# Crypto module: zsh tab completion.

_re_file_hash() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-r --recursive)'{-r,--recursive}'[walk directories, one line per file]' \
        '--algo[only these algorithms, comma-separated]:algorithms:(md5 sha1 sha224 sha256 sha384 sha512 sha3-256 sha3-512 blake2b crc32)' \
        '--dups[only the files sharing a digest, grouped]' \
        '--check[compare a digest with every algorithm]:digest: ' \
        '--vt[also print the VirusTotal URL for the SHA-256]' \
        '*:file or directory:_files'
}

_re_cert_info() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-o --output)'{-o,--output}'[write the PEM here]:file:_files' \
        '(-f --force)'{-f,--force}'[replace an existing output]' \
        '--leaf[only the first certificate of the chain]' \
        '--pem[output PEM instead of a report]' \
        '1:certificate file or host\[:port\]:_files'
}

_re_jwt_decode() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '--secret[verify an HS256/384/512 signature with this key]:secret: ' \
        '1:token: '
}

compdef _re_file_hash file-hash
compdef _re_cert_info cert-info
compdef _re_jwt_decode jwt-decode

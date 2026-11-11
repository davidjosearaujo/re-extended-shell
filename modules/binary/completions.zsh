# Binary module: zsh tab completion.

_re_bin_triage() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-n --min-length)'{-n,--min-length}'[shortest string to consider]:length: ' \
        '(-l --limit)'{-l,--limit}'[most lines shown per list]:lines: ' \
        '--decode[decode files over 32 MiB too]' \
        '--xor[also try every single-byte XOR key (slow)]' \
        '1:file:_files'
}

_re_proto_extract() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-o --output)'{-o,--output}'[output directory]:directory:_files -/' \
        '(-f --force)'{-f,--force}'[replace an existing output]' \
        '--all[also keep google/protobuf/*.proto]' \
        '*:file or directory:_files'
}

compdef _re_bin_triage bin-triage
compdef _re_proto_extract proto-extract

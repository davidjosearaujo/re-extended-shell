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

_re_so_exports() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-g --grep)'{-g,--grep}'[only symbols matching this regular expression]:pattern: ' \
        '(-l --limit --all)'{-l,--limit}'[most lines shown per list]:lines: ' \
        '(-l --limit --all)--all[show every symbol, however many]' \
        '--imports[also list the symbols it imports]' \
        '*:file:_files'
}

_re_frida_hook() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-o --output)'{-o,--output}'[where to write the script]:script:_files -g "*.js(-.)"' \
        '(-f --force)'{-f,--force}'[replace an existing output]' \
        '(-g --grep)'{-g,--grep}'[hook the exported functions matching this regular expression]:pattern: ' \
        '--args[arguments shown per call]:count: ' \
        '--backtrace[also print where each call came from]' \
        '1:shared library:_files' \
        '*:symbol: '
}

_re_crypto_find() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '--min-confidence[only hits at this level or above]:level:(low medium high)' \
        '*:file or directory:_files'
}

_re_crypto_libs() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '*:file or directory:_files'
}

compdef _re_bin_triage bin-triage
compdef _re_proto_extract proto-extract
compdef _re_so_exports so-exports
compdef _re_frida_hook frida-hook
compdef _re_crypto_find crypto-find
compdef _re_crypto_libs crypto-libs

# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/harness.sh"

# A text file with things to find
cat >"$T_DIR/sample.txt" <<'TXT'
visit http://evil.example.com/path now
callback 10.1.2.3 and nonsense 300.1.1.1 here
contact admin@evil.test please
config in /etc/passwd today
password=hunter2 is stored
TXT

run bin-triage "$T_DIR/sample.txt"
expect_rc 0 "text file: runs"
expect_out "== Identity ==" "has an identity section"
expect_out "Not an ELF, Mach-O or PE file" "...and says only the generic parts apply"
expect_out "http://evil.example.com/path" "finds URLs"
expect_out "10.1.2.3" "finds IP addresses"
expect_no_out "300.1.1.1" "...but not invalid ones"
expect_out "admin@evil.test" "finds e-mail addresses"
expect_out "/etc/passwd" "finds paths"
expect_out "password=hunter2" "finds password-like strings"

# Hashes of a known input
printf abc >"$T_DIR/abc"
run bin-triage "$T_DIR/abc"
expect_out "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" "SHA-256 of 'abc'"
expect_out "900150983cd24fb0d6963f7d28e17f72" "MD5 of 'abc'"

run bin-triage -n 30 "$T_DIR/sample.txt"
expect_out "(none)" "-n raises the shortest string"
run bin-triage -l 1 "$T_DIR/sample.txt"
expect_rc 0 "-l limits the lists"

# Entropy: random bytes are high, text is not
if command -v python3 >/dev/null 2>&1; then
    head -c 65536 /dev/urandom >"$T_DIR/random.bin"
    run bin-triage "$T_DIR/random.bin"
    expect_out "likely packed or encrypted" "random data: high entropy"
    expect_no_out "sampled" "a small file is read whole"
    run bin-triage "$T_DIR/sample.txt"
    expect_out "(normal)" "text: normal entropy"
else
    skip "entropy" "python3 not installed"
fi

# A real executable of this machine
case "$(uname -s)" in
    Linux)
        if command -v readelf >/dev/null 2>&1; then
            run bin-triage /bin/sh
            expect_rc 0 "ELF: /bin/sh"
            expect_out "Hardening (ELF)" "has the ELF hardening section"
            expect_out "PIE" "...with PIE"
            expect_out "RELRO" "...and RELRO"
            expect_out "libc.so" "lists the libraries"
        else
            skip "ELF" "readelf not installed"
        fi ;;
    Darwin)
        if command -v otool >/dev/null 2>&1; then
            run bin-triage /bin/ls
            expect_out "Hardening (Mach-O)" "has the Mach-O hardening section"
        else
            skip "Mach-O" "otool not installed"
        fi ;;
esac

# Mach-O on any system: a minimal header (file(1) reads its PIE flag), with
# stand-ins for otool and nm that report a PIE, signed binary with a canary
if [ "$(uname -s)" != Darwin ] || ! command -v otool >/dev/null 2>&1; then
    MACHO="$T_DIR/macho"
    mkdir -p "$MACHO/bin"
    printf '\317\372\355\376\007\000\000\001\003\000\000\000\002\000\000\000\000\000\000\000\000\000\000\000\205\000\040\000\000\000\000\000' >"$MACHO/app"
    head -c 64 /dev/zero >>"$MACHO/app"
    cat >"$MACHO/bin/otool" <<'EOF'
#!/bin/sh
case "$1" in
    -hv) printf 'Mach header\n      magic  cputype cpusubtype  caps    filetype ncmds sizeofcmds      flags\nMH_MAGIC_64   X86_64        ALL  0x00     EXECUTE     0          0   NOUNDEFS DYLDLINK TWOLEVEL PIE\n' ;;
    -l)  printf 'Load command 0\n      cmd LC_CODE_SIGNATURE\n' ;;
    -L)  printf '%s:\n\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0)\n' "$2" ;;
esac
EOF
    printf '#!/bin/sh\nprintf "___stack_chk_fail\\n_system\\n"\n' >"$MACHO/bin/nm"
    chmod +x "$MACHO/bin/otool" "$MACHO/bin/nm"
    if file -b "$MACHO/app" | grep -q Mach-O; then
        PATH="$MACHO/bin:$PATH" run bin-triage "$MACHO/app"
        expect_out "Hardening (Mach-O)" "Mach-O: has the hardening section"
        expect_out "PIE          yes" "...reads PIE from the header"
        expect_out "Canary       yes" "...the canary from the imports"
        expect_out "Signed       yes" "...the signature from the load commands"
        expect_out "libSystem.B.dylib" "...lists the libraries"
        expect_out "  system" "...and notable imports"
    else
        skip "Mach-O" "this file(1) doesn't recognise Mach-O"
    fi
fi

run bin-triage "$T_DIR/nope"
expect_rc 1 "a missing file is an error"
run bin-triage -n x "$T_DIR/sample.txt"
expect_rc 1 "a non-numeric length is an error"
run bin-triage "$T_DIR/sample.txt" "$T_DIR/random.bin"
expect_rc 1 "two files at once is an error"

done_testing

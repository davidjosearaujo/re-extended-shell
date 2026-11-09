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

run bin-triage "$T_DIR/nope"
expect_rc 1 "a missing file is an error"
run bin-triage -n x "$T_DIR/sample.txt"
expect_rc 1 "a non-numeric length is an error"
run bin-triage "$T_DIR/sample.txt" "$T_DIR/random.bin"
expect_rc 1 "two files at once is an error"

done_testing

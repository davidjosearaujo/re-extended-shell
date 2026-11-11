# shellcheck shell=bash
# re-doctor checks of the binary module. Sourced by core/bin/re-doctor, which
# provides the doc_* helpers. Read-only.

# shellcheck source=lib.sh
. "$RE_EXT_HOME/modules/binary/lib.sh"

doc_section "Binary: tools"
doc_tool required file "bin-triage" "Install your distribution's 'file' package." || true
# stringx reads the strings when installed; binutils strings is the fallback
if doc_tool optional stringx "bin-triage (UTF-16 strings, secret patterns, decoding) and app-data (keys in binary files)" \
        "Put stringx on your PATH; until then bin-triage uses binutils strings (ASCII only)."; then
    doc_info "$(stringx --version 2>/dev/null)"
else
    doc_tool required strings "bin-triage, as stringx isn't installed" "Install binutils (Linux) or the Xcode command line tools (macOS)." || true
fi
# What reads each file format
doc_tool optional readelf "bin-triage on ELF files" "Install binutils." || true
doc_tool optional objdump "bin-triage on PE files" "Install binutils." || true
if [ "$RE_OS" = Darwin ]; then
    doc_tool optional otool "bin-triage on Mach-O files" "xcode-select --install" || true
fi
doc_tool optional nm "bin-triage (imports of Mach-O files)" "Install binutils." || true
doc_tool optional python3 "bin-triage (entropy), proto-extract" || true

# shellcheck shell=bash
# RE Extended Shell - helpers for the binary module's commands (bin/).
# Sourced by those scripts (always bash), never by your interactive shell.
# Same portability rules as core/lib.sh: bash 3.2, GNU and BSD tools.

# shellcheck source=../core/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/../core/lib.sh"

# shellcheck disable=SC2034  # used by the scripts that source this file
RE_BINARY_DIR="$RE_EXT_HOME/modules/binary"   # libexec/ holds the helper programs

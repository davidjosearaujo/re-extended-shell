# PATH entries (sourced by bash and zsh).
# Topic-specific tools (e.g. the Android SDK) are added by config/<topic>.sh.

# Appends a directory to PATH if it exists and isn't there yet, so re-sourcing
# your rc file doesn't grow PATH. Also handy in local/paths.sh.
re_path_append() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) if [ -d "$1" ]; then PATH="$PATH:$1"; fi ;;
    esac
}

# Same, but puts the directory first
re_path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) if [ -d "$1" ]; then PATH="$1:$PATH"; fi ;;
    esac
}

# The RE Extended Shell commands
re_path_append "$RE_EXT_HOME/bin"

export PATH

# Core module: PATH helpers (sourced by bash and zsh).
# Loaded before every other module's paths.sh, so they can use these. Each
# module's bin/ is added by the loader.

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

# A JDK that's only known through JAVA_HOME (never added to PATH). Appended, so
# a java already on PATH keeps winning.
if [ -n "${JAVA_HOME:-}" ]; then
    re_path_append "$JAVA_HOME/bin"
fi

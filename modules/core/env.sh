# Core module: environment (sourced by bash and zsh).
# Loaded first, then local/env.sh, then every other module. A value set here
# (or inherited) is kept; local/env.sh can still override what this detects.

# Java: keep an existing JAVA_HOME, else look for a JDK, in this order:
#   1. macOS: the one /usr/libexec/java_home picks
#   2. the one behind 'java' on PATH
#   3. Homebrew's openjdk (keg-only: not on PATH, and invisible to java_home
#      unless linked into /Library/Java/JavaVirtualMachines), plain 'openjdk'
#      first, then the newest openjdk@N
# Left unset if there's none. paths.sh puts $JAVA_HOME/bin on PATH if no java is
# there yet, so a keg-only Homebrew JDK works without touching PATH yourself.
if [ -z "${JAVA_HOME:-}" ]; then
    if [ -x /usr/libexec/java_home ] && _re_java=$(/usr/libexec/java_home 2>/dev/null) && [ -n "$_re_java" ]; then
        JAVA_HOME="$_re_java"
    else
        if _re_java=$(command -v java 2>/dev/null) && [ -n "$_re_java" ]; then
            _re_java=$(readlink -f "$_re_java" 2>/dev/null) || _re_java=""
            # <home>/bin/java, or <home>/jre/bin/java on a JDK 8
            _re_java=${_re_java%/bin/java}
            _re_java=${_re_java%/jre}
            # /usr is macOS's java stub (it fails when no JDK is installed)
            if [ -n "$_re_java" ] && [ "$_re_java" != /usr ] && [ -x "$_re_java/bin/java" ]; then
                JAVA_HOME="$_re_java"
            fi
        fi
        if [ -z "${JAVA_HOME:-}" ]; then
            for _re_brew in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
                [ -d "$_re_brew/opt" ] || continue
                while IFS= read -r _re_java; do
                    # macOS formula: libexec/openjdk.jdk/Contents/Home; Linux: libexec
                    for _re_home in "$_re_java/libexec/openjdk.jdk/Contents/Home" "$_re_java/libexec"; do
                        if [ -x "$_re_home/bin/java" ]; then JAVA_HOME="$_re_home"; break 2; fi
                    done
                done <<EOF2
$_re_brew/opt/openjdk
$(find "$_re_brew/opt" -maxdepth 1 -name 'openjdk@*' 2>/dev/null | sort -rV)
EOF2
                [ -z "${JAVA_HOME:-}" ] || break
            done
            unset _re_brew _re_home
        fi
    fi
    unset _re_java
fi
if [ -n "${JAVA_HOME:-}" ]; then export JAVA_HOME; fi

# Settings read by the commands of every module (defaults shown, override in
# local/env.sh):
#   RE_ZAP_PORT=9090                                  ZAP proxy port on this machine
#   RE_ZAP_CERT="$RE_EXT_HOME/certs/zap_root_ca.cer"  ZAP root CA, PEM or DER
#   JAVA_HOME=<the JDK behind 'java', or Homebrew's>  for the commands that run Java

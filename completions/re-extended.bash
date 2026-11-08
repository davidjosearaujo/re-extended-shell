# shellcheck shell=bash
# Bash tab completion for the RE Extended Bash commands.

# AVD names, read from the .ini files (much faster than 'emulator -list-avds')
_re_avds() {
    local f
    for f in "${ANDROID_AVD_HOME:-$HOME/.android/avd}"/*.ini; do
        [ -e "$f" ] || continue
        f=${f##*/}
        echo "${f%.ini}"
    done
}

# Serials of connected devices (--physical: skip emulators)
_re_serials() {
    command -v adb >/dev/null 2>&1 || return 0
    if [ "${1:-}" = "--physical" ]; then
        adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ { print $1 }'
    else
        adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" { print $1 }'
    fi
}

# COMPREPLY = words from $1 matching the current word
_re_reply_words() {
    mapfile -t COMPREPLY < <(compgen -W "$1" -- "$cur")
}

# COMPREPLY = directories + files whose extension is in $1 (e.g. "xapk|zip")
_re_reply_files() {
    local f files=()
    COMPREPLY=()
    mapfile -t files < <(compgen -f -- "$cur")
    for f in "${files[@]}"; do
        if [ -d "$f" ]; then
            COMPREPLY+=("$f")
        elif [ -z "$1" ] || [[ "${f,,}" =~ \.($1)$ ]]; then
            COMPREPLY+=("$f")
        fi
    done
    compopt -o filenames 2>/dev/null
}

_re_complete_launch_emulator() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -d|--device) _re_reply_words "$(_re_serials --physical)"; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "--clean --wiped -d --device -h --help"
    else
        _re_reply_words "$(_re_avds)"
    fi
}

_re_complete_kill_emulator() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-f --force -h --help"
    else
        _re_reply_words "$(_re_avds)"
    fi
}

_re_complete_release_device() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    if [[ "$cur" == -* ]]; then
        _re_reply_words "--reboot -h --help"
    else
        _re_reply_words "$(_re_serials --physical)"
    fi
}

_re_complete_wireshark() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -s|--serial)    _re_reply_words "$(_re_serials)"; return ;;
        -i|--interface) _re_reply_words "any wlan0 eth0 lo"; return ;;
    esac
    _re_reply_words "-s --serial -i --interface -h --help"
}

_re_complete_xapk_installer() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -s|--serial) _re_reply_words "$(_re_serials)"; return ;;
        -n|--name)   _re_reply_words "$(_re_avds)"; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-s --serial -n --name -h --help"
    else
        _re_reply_files "xapk|zip"
    fi
}

_re_complete_xapk_merger() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -o|--output)   _re_reply_files "apk"; return ;;
        -k|--keystore) _re_reply_files ""; return ;;
        -j|--jar)      _re_reply_files "jar"; return ;;
        -p|--ks-pass|-a|--alias) COMPREPLY=(); return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-o --output -k --keystore -p --ks-pass -a --alias -j --jar --no-obb -h --help"
    else
        _re_reply_files "xapk|zip|apks"
    fi
}

_re_complete_androidcontainer() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    _re_reply_words "-h --help"
}

complete -F _re_complete_launch_emulator launch-emulator
complete -F _re_complete_kill_emulator kill-emulator
complete -F _re_complete_release_device release-device
complete -F _re_complete_wireshark launch-emulator-wireshark
complete -F _re_complete_xapk_installer xapk-installer
complete -F _re_complete_xapk_merger xapk-merger
complete -F _re_complete_androidcontainer androidcontainer

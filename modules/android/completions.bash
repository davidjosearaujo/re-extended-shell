# shellcheck shell=bash
# Android module: bash tab completion (helpers in modules/core/completions.bash).

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

# Value of -s/--serial earlier on the command line, if any
_re_comp_serial() {
    local i
    for ((i = 1; i < COMP_CWORD; i++)); do
        case "${COMP_WORDS[i]}" in
            -s|--serial) echo "${COMP_WORDS[i+1]}"; return ;;
        esac
    done
}

# Packages installed on the device given with -s (or the only one connected)
_re_packages() {
    command -v adb >/dev/null 2>&1 || return 0
    local serial
    serial=$(_re_comp_serial)
    adb ${serial:+-s "$serial"} shell pm list packages 2>/dev/null | tr -d '\r' | sed 's/^package://'
}

_re_complete_launch_emulator() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -s|--serial) _re_reply_words "$(_re_serials --physical)"; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "--clean --start-frida-server --no-frida -d --device -s --serial -h --help"
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

_re_complete_reset_emulator() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -s|--serial) _re_reply_words "$(_re_serials | grep '^emulator-')"; return ;;
        -n|--name)   _re_reply_words "$(_re_avds)"; return ;;
        --snapshot)  COMPREPLY=(); return ;;
    esac
    _re_reply_words "-s --serial -n --name --save --snapshot -h --help"
}

_re_complete_device_proxy() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]} i seen=""
    case "$prev" in
        -s|--serial) _re_reply_words "$(_re_serials)"; return ;;
    esac
    for ((i = 1; i < COMP_CWORD; i++)); do
        case "${COMP_WORDS[i]}" in on|off|status) seen=1 ;; esac
    done
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-s --serial -h --help"
    elif [ -z "$seen" ]; then
        _re_reply_words "on off status"
    else
        COMPREPLY=()
    fi
}

_re_complete_release_device() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -s|--serial) _re_reply_words "$(_re_serials --physical)"; return ;;
    esac
    _re_reply_words "-s --serial --reboot -h --help"
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
        _re_reply_words "-o --output -f --force -k --keystore -p --ks-pass -a --alias -j --jar --no-obb --provision -h --help"
    else
        _re_reply_files "xapk|zip|apks"
    fi
}

_re_complete_androidcontainer() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    _re_reply_words "-h --help"
}

_re_complete_frida_server() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -s|--serial)     _re_reply_words "$(_re_serials)"; return ;;
        --ssl-unpinning) _re_reply_words "$(_re_packages)"; return ;;
        -l|--load)       _re_reply_files "js"; return ;;
    esac
    _re_reply_words "-s --serial --ssl-unpinning -l --load --refresh --push-only --stop -h --help"
}

_re_complete_apk_pull() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -s|--serial)   _re_reply_words "$(_re_serials)"; return ;;
        -o|--output)   _re_reply_files "apk"; return ;;
        -k|--keystore) _re_reply_files ""; return ;;
        -p|--ks-pass|-a|--alias) COMPREPLY=(); return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-s --serial -o --output -f --force --merge -k --keystore -p --ks-pass -a --alias -h --help"
    else
        _re_reply_words "$(_re_packages)"
    fi
}

_re_complete_apk_decompile() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -o|--output) _re_reply_dirs; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-o --output --jadx-only --apktool-only --deobf -f --force -h --help"
    else
        _re_reply_files "apk"
    fi
}

_re_complete_apk_patch() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -o|--output)   _re_reply_files "apk"; return ;;
        -k|--keystore) _re_reply_files ""; return ;;
        -p|--ks-pass|-a|--alias) COMPREPLY=(); return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-o --output -f --force -k --keystore -p --ks-pass -a --alias --no-debuggable -h --help"
    else
        _re_reply_files "apk"
    fi
}

_re_complete_applog() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]} i
    for ((i = 1; i < COMP_CWORD; i++)); do
        [ "${COMP_WORDS[i]}" = "--" ] && { COMPREPLY=(); return; }   # logcat's own arguments
    done
    case "$prev" in
        -s|--serial) _re_reply_words "$(_re_serials)"; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-s --serial --start -h --help --"
    else
        _re_reply_words "$(_re_packages)"
    fi
}

complete -F _re_complete_launch_emulator launch-emulator
complete -F _re_complete_kill_emulator kill-emulator
complete -F _re_complete_reset_emulator reset-emulator
complete -F _re_complete_device_proxy device-proxy
complete -F _re_complete_release_device release-device
complete -F _re_complete_wireshark launch-emulator-wireshark
complete -F _re_complete_xapk_installer xapk-installer
complete -F _re_complete_xapk_merger xapk-merger
complete -F _re_complete_androidcontainer androidcontainer
complete -F _re_complete_frida_server frida-server
complete -F _re_complete_apk_pull apk-pull
complete -F _re_complete_apk_decompile apk-decompile
complete -F _re_complete_apk_patch apk-patch
complete -F _re_complete_applog applog

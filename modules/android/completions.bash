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

# The adb serial for ID, a device serial or the AVD name of a running emulator
# (either flag takes either). Prints ID unchanged when nothing matches.
_re_resolve_serial() {
    local s
    if [ "$(adb -s "$1" get-state 2>/dev/null)" != "device" ]; then
        for s in $(adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" && $1 ~ /^emulator-/ { print $1 }'); do
            if [ "$(adb -s "$s" emu avd name 2>/dev/null | head -n 1 | tr -d '\r')" = "$1" ]; then
                echo "$s"; return
            fi
        done
    fi
    echo "$1"
}

# Serial of the device given with -s/--serial or -n/--name earlier on the
# command line, if any
_re_comp_serial() {
    local i
    for ((i = 1; i < COMP_CWORD; i++)); do
        case "${COMP_WORDS[i]}" in
            -s|--serial|-n|--name)
                [ -n "${COMP_WORDS[i+1]:-}" ] && _re_resolve_serial "${COMP_WORDS[i+1]}"
                return ;;
        esac
    done
}

# Packages installed on the device given with -s or -n (or the only one connected)
_re_packages() {
    command -v adb >/dev/null 2>&1 || return 0
    local serial
    serial=$(_re_comp_serial)
    adb ${serial:+-s "$serial"} shell pm list packages 2>/dev/null | tr -d '\r' | sed 's/^package://'
}

_re_complete_launch_emulator() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        # -s takes a phone or the serial of a running emulator (its AVD)
        -s|--serial) _re_reply_words "$(_re_serials)"; return ;;
        --proxy) return ;;
        --ca) _re_reply_files "cer|crt|pem|der"; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "--snapshot --clean --read-only --push-frida-server --start-frida-server --proxy --ca -d --device -s --serial -h --help"
    else
        _re_reply_words "$(_re_avds)"
    fi
}

_re_complete_kill_emulator() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-f --force -h --help"
    else
        # An AVD name or a running emulator's serial, both of which it takes
        _re_reply_words "$(_re_avds)
$(_re_serials | grep '^emulator-')"
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
        -n|--name)   _re_reply_words "$(_re_avds)"; return ;;
    esac
    for ((i = 1; i < COMP_CWORD; i++)); do
        case "${COMP_WORDS[i]}" in on|off|status) seen=1 ;; esac
    done
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-s --serial -n --name -h --help"
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
        -n|--name)   _re_reply_words "$(_re_avds)"; return ;;
        -i|--interface) _re_reply_words "any wlan0 eth0 lo"; return ;;
    esac
    _re_reply_words "-s --serial -n --name -i --interface -h --help"
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
        -n|--name)       _re_reply_words "$(_re_avds)"; return ;;
        --ssl-unpinning) _re_reply_words "$(_re_packages)"; return ;;
        -l|--load)       _re_reply_files "js"; return ;;
    esac
    _re_reply_words "-s --serial -n --name --ssl-unpinning -l --load --refresh --push-only --stop -h --help"
}

_re_complete_apk_pull() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -s|--serial)   _re_reply_words "$(_re_serials)"; return ;;
        -n|--name)  _re_reply_words "$(_re_avds)"; return ;;
        -o|--output)   _re_reply_files "apk"; return ;;
        -k|--keystore) _re_reply_files ""; return ;;
        -p|--ks-pass|-a|--alias) COMPREPLY=(); return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-s --serial -n --name -o --output -f --force --merge -k --keystore -p --ks-pass -a --alias -h --help"
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
        -n|--name) _re_reply_words "$(_re_avds)"; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-s --serial -n --name --start -h --help --"
    else
        _re_reply_words "$(_re_packages)"
    fi
}

_re_complete_apk_info() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -s|--serial) _re_reply_words "$(_re_serials)"; return ;;
        -n|--name) _re_reply_words "$(_re_avds)"; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-s --serial -n --name --all -h --help"
        return
    fi
    # APK files, plus the device's packages unless the word is clearly a path
    _re_reply_files "apk"
    [[ "$cur" == */* || "$cur" == .* ]] && return
    local files=(${COMPREPLY[@]+"${COMPREPLY[@]}"})
    _re_reply_words "$(_re_packages)"
    COMPREPLY=(${files[@]+"${files[@]}"} ${COMPREPLY[@]+"${COMPREPLY[@]}"})
}

_re_complete_app_data() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in
        -s|--serial)        _re_reply_words "$(_re_serials)"; return ;;
        -n|--name)       _re_reply_words "$(_re_avds)"; return ;;
        -o|--output|--diff) _re_reply_dirs; return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-s --serial -n --name -o --output -f --force --diff -h --help"
    else
        _re_reply_words "$(_re_packages)"
    fi
}

_re_complete_app_intent() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]} i n=0
    for ((i = 1; i < COMP_CWORD; i++)); do
        case "${COMP_WORDS[i]}" in
            --) COMPREPLY=(); return ;;   # am/content arguments
            -s|--serial|-n|--name|--action|--data|-e|--extra) ((i++)) ;;
            -*) ;;
            *) n=$((n + 1)) ;;
        esac
    done
    case "$prev" in
        -s|--serial) _re_reply_words "$(_re_serials)"; return ;;
        -n|--name) _re_reply_words "$(_re_avds)"; return ;;
        --action) _re_reply_words "android.intent.action.VIEW android.intent.action.SEND android.intent.action.MAIN android.intent.action.BOOT_COMPLETED"; return ;;
        --data|-e|--extra) COMPREPLY=(); return ;;
    esac
    if [[ "$cur" == -* ]]; then
        _re_reply_words "-s --serial -n --name --all --root --action --data -e --extra -h --help --"
    elif [ "$n" -eq 0 ]; then
        _re_reply_words "$(_re_packages)"
    else
        COMPREPLY=()
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
complete -F _re_complete_apk_info apk-info
complete -F _re_complete_app_data app-data
complete -F _re_complete_app_intent app-intent

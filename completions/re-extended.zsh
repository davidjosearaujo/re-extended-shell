# Zsh tab completion for the RE Extended Shell commands.

# compdef only exists once the completion system is initialised. Most setups
# (oh-my-zsh, prezto, ...) do that before this file is sourced; if not, do it.
if (( ! $+functions[compdef] )); then
    autoload -Uz compinit && compinit -i
fi

_re_avds() {
    local -a avds
    avds=( ${ANDROID_AVD_HOME:-$HOME/.android/avd}/*.ini(N:t:r) )
    _describe -t avds 'AVD' avds
}

_re_serials() {
    local -a serials
    (( $+commands[adb] )) || return 1
    if [[ $1 == --physical ]]; then
        serials=( ${(f)"$(adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ { print $1 }')"} )
    else
        serials=( ${(f)"$(adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" { print $1 }')"} )
    fi
    _describe -t serials 'device serial' serials
}

_re_launch_emulator() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(--clean --wiped -d --device)'{--clean,--wiped}'[wiped boot, ignoring the snapshot]' \
        '(--clean --wiped -d --device 1)'{-d,--device}'[use a connected physical device]::device serial:_re_serials --physical' \
        '1:AVD name:_re_avds'
}

_re_kill_emulator() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-f --force)'{-f,--force}'[kill the process right away]' \
        '1:AVD name:_re_avds'
}

_re_release_device() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '--reboot[also reboot, dropping the injected CA]' \
        '1:device serial:_re_serials --physical'
}

_re_wireshark() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial)'{-s,--serial}'[device to capture from]:device serial:_re_serials' \
        '(-i --interface)'{-i,--interface}'[device interface]:interface:(any wlan0 eth0 lo)'
}

_re_xapk_installer() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial -n --name)'{-s,--serial}'[target device]:device serial:_re_serials' \
        '(-s --serial -n --name)'{-n,--name}'[target running emulator by AVD name]:AVD name:_re_avds' \
        '1:XAPK file:_files -g "*.(#i)(xapk|zip)(-.)"'
}

_re_xapk_merger() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-o --output)'{-o,--output}'[output APK]:output APK:_files -g "*.(#i)apk(-.)"' \
        '(-k --keystore)'{-k,--keystore}'[keystore to sign with]:keystore:_files' \
        '(-p --ks-pass)'{-p,--ks-pass}'[keystore password]:password: ' \
        '(-a --alias)'{-a,--alias}'[key alias]:alias: ' \
        '(-j --jar)'{-j,--jar}'[APKEditor jar]:jar:_files -g "*.(#i)jar(-.)"' \
        '--no-obb[do not copy OBB data]' \
        '1:XAPK/APKS file:_files -g "*.(#i)(xapk|zip|apks)(-.)"'
}

_re_androidcontainer() {
    _arguments '(- *)'{-h,--help}'[show help]'
}

compdef _re_launch_emulator launch-emulator
compdef _re_kill_emulator kill-emulator
compdef _re_release_device release-device
compdef _re_wireshark launch-emulator-wireshark
compdef _re_xapk_installer xapk-installer
compdef _re_xapk_merger xapk-merger
compdef _re_androidcontainer androidcontainer

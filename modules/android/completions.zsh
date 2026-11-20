# Android module: zsh tab completion.

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

# An AVD name or a running emulator's serial: kill-emulator takes either
_re_avd_or_emulator() {
    local -a serials
    _re_avds
    (( $+commands[adb] )) || return
    serials=( ${(f)"$(adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" && $1 ~ /^emulator-/ { print $1 }')"} )
    _describe -t serials 'emulator serial' serials
}

# Packages installed on the device given with -s or -n (or the only one
# connected); either flag takes a serial or a running emulator's AVD name.
# Called from _arguments, which fills $opt_args.
_re_packages() {
    local -a pkgs args
    local s serial=${opt_args[-s]:-${opt_args[--serial]:-${opt_args[-n]:-${opt_args[--name]}}}}
    (( $+commands[adb] )) || return 1
    if [[ -n $serial && "$(adb -s $serial get-state 2>/dev/null)" != device ]]; then
        for s in ${(f)"$(adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" && $1 ~ /^emulator-/ { print $1 }')"}; do
            if [[ "$(adb -s $s emu avd name 2>/dev/null | head -n 1 | tr -d '\r')" == $serial ]]; then
                serial=$s; break
            fi
        done
    fi
    [[ -n $serial ]] && args=(-s $serial)
    pkgs=( ${(f)"$(adb $args shell pm list packages 2>/dev/null | tr -d '\r' | sed 's/^package://')"} )
    _describe -t packages 'package' pkgs
}

_re_launch_emulator() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-d --device -s --serial)--snapshot[boot from the snapshot, saving it first if needed]' \
        '(-d --device -s --serial --read-only)--clean[wiped boot that replaces the snapshot]' \
        '(-d --device -s --serial --clean)--read-only[keep nothing from this session]' \
        '--push-frida-server[push frida-server without starting it]' \
        '--start-frida-server[push frida-server and start it]' \
        '--proxy[proxy the traffic to this port on this machine (needs --ca)]:port' \
        '--ca[inject this CA as a system CA (needs --proxy)]:certificate:_files' \
        '(--snapshot --clean --read-only 1)'{-d,--device}'[use a connected physical device]' \
        '(--snapshot --clean --read-only -s --serial 1)'{-s,--serial}'[device to use: a phone (implies -d) or a running emulator]:device serial:_re_serials' \
        '1:AVD name:_re_avds'
}

_re_kill_emulator() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-f --force)'{-f,--force}'[kill the process right away]' \
        '1:AVD name or emulator serial:_re_avd_or_emulator'
}

_re_device_proxy() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial -n --name)'{-s,--serial}'[device to use]:device serial:_re_serials' \
        '(-s --serial -n --name)'{-n,--name}'[running emulator to use, by AVD name]:AVD name:_re_avds' \
        '1:action:(on off status)'
}

_re_reset_emulator() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial -n --name)'{-s,--serial}'[emulator to use, by serial]:emulator serial:_re_serials' \
        '(-s --serial -n --name)'{-n,--name}'[emulator to use, by AVD name]:AVD name:_re_avds' \
        '--save[save the current state as the snapshot]' \
        '--snapshot[snapshot to use]:snapshot name: '
}

_re_release_device() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial)'{-s,--serial}'[device to release]:device serial:_re_serials --physical' \
        '--reboot[also reboot, dropping the injected CA]'
}

_re_wireshark() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial -n --name)'{-s,--serial}'[device to capture from]:device serial:_re_serials' \
        '(-s --serial -n --name)'{-n,--name}'[running emulator to use, by AVD name]:AVD name:_re_avds' \
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
        '(-f --force)'{-f,--force}'[replace an existing output]' \
        '(-k --keystore)'{-k,--keystore}'[keystore to sign with]:keystore:_files' \
        '(-p --ks-pass)'{-p,--ks-pass}'[keystore password]:password: ' \
        '(-a --alias)'{-a,--alias}'[key alias]:alias: ' \
        '(-j --jar)'{-j,--jar}'[APKEditor jar]:jar:_files -g "*.(#i)jar(-.)"' \
        '--no-obb[do not copy OBB data]' \
        '--provision[download APKEditor, or update it to the latest release]' \
        '1:XAPK/APKS file or directory of APKs:_files -g "*.(#i)(xapk|zip|apks)(-.)"'
}

_re_androidcontainer() {
    _arguments '(- *)'{-h,--help}'[show help]'
}

_re_frida_server() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial -n --name)'{-s,--serial}'[device to use]:device serial:_re_serials' \
        '(-s --serial -n --name)'{-n,--name}'[running emulator to use, by AVD name]:AVD name:_re_avds' \
        '(--stop)--ssl-unpinning[spawn an app with SSL unpinning]:package:_re_packages' \
        '(--stop)*'{-l,--load}'[extra Frida script]:script:_files -g "*.js(-.)"' \
        '(--stop)--refresh[download frida-server and the scripts again]' \
        '(--stop --ssl-unpinning)--push-only[push the binary without starting it]' \
        '(--ssl-unpinning -l --load --refresh)--stop[kill frida-server on the device]'
}

_re_apk_pull() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial -n --name)'{-s,--serial}'[device to pull from]:device serial:_re_serials' \
        '(-s --serial -n --name)'{-n,--name}'[running emulator to use, by AVD name]:AVD name:_re_avds' \
        '(-o --output)'{-o,--output}'[output directory, or APK with --merge]:output:_files' \
        '(-f --force)'{-f,--force}'[replace an existing output]' \
        '--merge[save a single merged APK]' \
        '(-k --keystore)'{-k,--keystore}'[with --merge, keystore to sign with]:keystore:_files' \
        '(-p --ks-pass)'{-p,--ks-pass}'[keystore password]:password: ' \
        '(-a --alias)'{-a,--alias}'[key alias]:alias: ' \
        '1:package:_re_packages'
}

_re_apk_decompile() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-o --output)'{-o,--output}'[output directory]:directory:_files -/' \
        '(--apktool-only)--jadx-only[only run jadx]' \
        '(--jadx-only)--apktool-only[only run apktool]' \
        '--deobf[deobfuscate names with jadx]' \
        '(-f --force)'{-f,--force}'[replace existing output]' \
        '1:APK file:_files -g "*.(#i)apk(-.)"'
}

_re_apk_patch() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-o --output)'{-o,--output}'[output APK]:output APK:_files -g "*.(#i)apk(-.)"' \
        '(-f --force)'{-f,--force}'[replace an existing output]' \
        '(-k --keystore)'{-k,--keystore}'[keystore to sign with]:keystore:_files' \
        '(-p --ks-pass)'{-p,--ks-pass}'[keystore password]:password: ' \
        '(-a --alias)'{-a,--alias}'[key alias]:alias: ' \
        '--no-debuggable[leave android\:debuggable as it is]' \
        '1:APK file:_files -g "*.(#i)apk(-.)"'
}

_re_applog() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial -n --name)'{-s,--serial}'[device to use]:device serial:_re_serials' \
        '(-s --serial -n --name)'{-n,--name}'[running emulator to use, by AVD name]:AVD name:_re_avds' \
        '--start[force-stop and launch the app first]' \
        '1:package:_re_packages' \
        '*::logcat argument: '
}

_re_apk_or_package() {
    _alternative 'files:APK file:_files -g "*.(#i)apk(-.)"' 'packages:package:_re_packages'
}

_re_apk_info() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial -n --name)'{-s,--serial}'[device to pull the app from]:device serial:_re_serials' \
        '(-s --serial -n --name)'{-n,--name}'[running emulator to use, by AVD name]:AVD name:_re_avds' \
        '--all[also list components that are not exported]' \
        '1:APK file or package:_re_apk_or_package'
}

_re_app_data() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial -n --name)'{-s,--serial}'[device to pull from]:device serial:_re_serials' \
        '(-s --serial -n --name)'{-n,--name}'[running emulator to use, by AVD name]:AVD name:_re_avds' \
        '(-o --output)'{-o,--output}'[output directory]:directory:_files -/' \
        '(-f --force)'{-f,--force}'[replace an existing output]' \
        '--diff[show what changed since an earlier copy]:earlier copy:_files -/' \
        '1:package:_re_packages'
}

_re_app_intent() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-s --serial -n --name)'{-s,--serial}'[device to use]:device serial:_re_serials' \
        '(-s --serial -n --name)'{-n,--name}'[running emulator to use, by AVD name]:AVD name:_re_avds' \
        '--all[also list components that are not exported]' \
        '--root[run as root, reaching components that are not exported]' \
        '--action[intent action]:action:(android.intent.action.VIEW android.intent.action.SEND android.intent.action.MAIN android.intent.action.BOOT_COMPLETED)' \
        '--data[intent data URI]:URI: ' \
        '*'{-e,--extra}'[string extra]:KEY=VALUE: ' \
        '1:package:_re_packages' \
        '2:component (number or name): ' \
        '*::am argument: '
}

compdef _re_launch_emulator launch-emulator
compdef _re_kill_emulator kill-emulator
compdef _re_reset_emulator reset-emulator
compdef _re_device_proxy device-proxy
compdef _re_release_device release-device
compdef _re_wireshark launch-emulator-wireshark
compdef _re_xapk_installer xapk-installer
compdef _re_xapk_merger xapk-merger
compdef _re_androidcontainer androidcontainer
compdef _re_frida_server frida-server
compdef _re_apk_pull apk-pull
compdef _re_apk_decompile apk-decompile
compdef _re_apk_patch apk-patch
compdef _re_applog applog
compdef _re_apk_info apk-info
compdef _re_app_data app-data
compdef _re_app_intent app-intent

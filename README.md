# RE Extended Shell

Shell tooling for reverse engineering and security testing, for bash and zsh on Linux
and macOS.

It's one place for the commands, environment setup and tab completion that RE work
needs, organised in modules, one per theme. Each module brings its own commands,
environment, PATH entries, aliases and completions, and everything installs and
uninstalls with a single hook in your shell's rc file. Your personal settings live in a
git-ignored `local/` folder, so updates never conflict with them.

**Modules:**

- [Android](#android): emulators and rooted phones with ZAP's CA injected as a system
  CA (Android 14+ included), Frida with SSL unpinning, pulling, decompiling and
  patching APKs, split APK/XAPK handling, per-app logs and live traffic capture.
- [Core](#core): what every module shares, and `re-doctor`, which checks your setup.

More modules will follow. See [Adding a module](#adding-a-module).

## Requirements

- Linux or macOS. The commands run on any bash from 3.2 up, so macOS's built-in
  `/bin/bash` is enough; your own shell can be bash or zsh
- [ZAP](https://www.zaproxy.org/) for the modules that intercept traffic, listening on
  `127.0.0.1:9090` by default (change with `RE_ZAP_PORT`)
- Each module's own tools, listed in its section. `re-doctor` tells you what's missing.

On macOS, bash in a terminal runs as a login shell and reads `~/.bash_profile`, not
`~/.bashrc`. The installer takes care of that (see below). zsh, the default shell,
needs nothing extra.

## Install

```sh
git clone <this repo> ~/re-extended-shell
cd ~/re-extended-shell
./install            # or: ./install --bash / ./install --zsh
```

The installer adds one line to `~/.bashrc` and/or `~/.zshrc`, under an
`# Installed by RE Extended Shell` comment, that sources `re_extended_shell_main`.
On macOS, if `~/.bash_profile` doesn't load `~/.bashrc`, the line goes there too; if
there's no `~/.bash_profile` at all, it creates the usual one that loads `~/.profile` and `~/.bashrc`.
It also fills `local/` with commented templates for your settings, without touching
files that are already there.
Running it again is safe: it updates that line in place, for example after you move
the repo, and adds the templates of any new module.

`./uninstall` removes the hook and lists what the commands created outside the repo.
`./uninstall --purge` also deletes those (downloads, caches, the `zap-ready` snapshots
of your AVDs). Neither touches the repo itself, so delete it afterwards to remove your
`local/` settings and `certs/` too.

Then export ZAP's root CA certificate to `certs/zap_root_ca.cer`, either from
*Tools → Options → Network → Server Certificates → Save*, or with
`zap.sh -cmd -certpubdump certs/zap_root_ca.cer`. PEM and DER both work. Each module
converts it to whatever format its targets expect.

Finally, run `re-doctor` to check that everything is in place.

## Core

| Command | What it does |
| --- | --- |
| `re-doctor [MODULE...]` | Checks the shell hook and PATH, the ZAP certificate (format, expiry) and whether ZAP is listening, then each module's tools, emulators and connected devices, and says how to fix what's missing. Read-only. Exits non-zero if something required is missing. |

Settings shared by every module (put them in `local/env.sh`):

| Variable | Default |
| --- | --- |
| `RE_ZAP_PORT` | `9090` |
| `RE_ZAP_CERT` | `certs/zap_root_ca.cer` |
| `JAVA_HOME` | the JDK behind `java` on PATH, else a Homebrew `openjdk` (its `bin/` is added to PATH if no `java` is there yet) |

## Android

### Commands

| Command | What it does |
| --- | --- |
| `launch-emulator <AVD>` | Boots the AVD, injects the ZAP CA as a system CA and sets the global HTTP proxy to ZAP. The first boot saves a `zap-ready` snapshot, so later boots take seconds. `--clean` does a wiped boot that ignores the old snapshot and replaces it with a fresh one. Also pushes the matching frida-server build to the device (without starting it) when Frida is installed; `--start-frida-server` starts it too, `--no-frida` skips the push. |
| `launch-emulator -d [SERIAL]` | Same setup on a rooted physical device (userdebug build, or `su` via Magisk/KernelSU). Routes the proxy through `adb reverse`, opens [scrcpy](https://github.com/Genymobile/scrcpy) and pushes frida-server the same way. |
| `release-device [--reboot] [SERIAL]` | Undoes `launch-emulator -d`: clears the proxy, removes the tunnel, stops frida-server, deletes the pushed files and closes scrcpy. Run it before unplugging the phone, or its network stops working. |
| `kill-emulator [-f] <AVD>` | Shuts an emulator down cleanly by AVD name, killing it only if it won't exit. |
| `frida-server [-s SERIAL]` | Downloads the frida-server build that matches your `frida --version` and the device's CPU, pushes it and starts it as root. Does nothing if that version already runs. `--push-only` stops after the push, `--stop` kills it, `--refresh` downloads again. |
| `frida-server --ssl-unpinning <PKG>` | Then spawns the app under Frida with [HTTP Toolkit's unpinning scripts](https://github.com/httptoolkit/frida-interception-and-unpinning): it trusts the ZAP CA despite certificate pinning, and is forced through the same proxy `launch-emulator` sets. `-l script.js` loads your own scripts too. |
| `apk-pull [-s SERIAL] <PKG>` | Pulls every APK of an installed app (base + splits) into `./<PKG>-splits/`. With `--merge`, saves a single installable `./<PKG>.apk` instead (merged with `xapk-merger` when the app has splits). |
| `apk-decompile <file.apk>` | Decompiles into `./<name>/jadx/` (Java, with [jadx](https://github.com/skylot/jadx)) and `./<name>/apktool/` (smali, manifest and resources, with [apktool](https://apktool.org)), running whichever is installed. |
| `apk-patch <file.apk>` | For phones you can't root: makes the app trust user CAs and the ZAP CA (embedded in the APK), overriding `<pin-set>`s, allows cleartext, sets `debuggable`, then rebuilds and signs it. |
| `applog [-s SERIAL] [--start] <PKG>` | `logcat` for that app's process only. Waits for it to start and follows it across restarts. `--start` (re)launches it; arguments after `--` go to logcat. |
| `launch-emulator-wireshark [-s SERIAL] [-i IFACE]` | Streams `tcpdump` from the device into a local Wireshark window. |
| `xapk-installer [-s SERIAL \| -n AVD] <file.xapk>` | Installs every split in an XAPK/ZIP bundle with `adb install-multiple` and pushes any OBB data. |
| `xapk-merger [options] <file.xapk\|.apks\|dir>` | Merges the splits (of a bundle, or a directory of APKs) into one installable APK with [APKEditor](https://github.com/REAndroid/APKEditor), downloaded on first use. Then zipaligns it and signs it with the debug keystore or your own (`-k`). `xapk-merger --provision` downloads APKEditor ahead of time, or updates it to the latest release. |
| `androidcontainer` | Runs Google's Android emulator container (podman or docker) and connects adb to it as root. Linux only, it needs KVM. |

Every command takes `-h`/`--help`, and all of them have tab completion in bash and zsh,
including AVD names, device serials and the packages installed on the device.

A typical session with an app that pins its certificates:

```sh
launch-emulator Pixel_8_API_34          # CA injected, proxied through ZAP, frida-server pushed
xapk-installer app.xapk                 # or install it from the Play Store
frida-server --ssl-unpinning com.example.app
applog com.example.app                  # in another terminal
apk-pull --merge com.example.app && apk-decompile com.example.app.apk
```

### Requirements

- Android SDK platform-tools and emulator, `openssl`. The SDK is found in the default
  Android Studio location; set `ANDROID_HOME` in `local/android.sh` if yours is elsewhere.
- For emulators: a **Google APIs** system image. Google Play images don't allow `adb root`.
- Optional, per command:
  - `frida-server`: [frida-tools](https://frida.re) (`pipx install frida-tools`), plus
    `xz` or `python3` to unpack the download
  - `apk-decompile`: jadx and/or apktool. jadx has no `apt` package (brew,
    flatpak, a release binary or a manual build); if it isn't `jadx` on your
    PATH, point `JADX` (and `JADX_GUI`) at it, arguments included
  - `apk-patch`: apktool **2.9 or newer** (older ones, like many distributions ship,
    can't rebuild most current apps), Java and the SDK build-tools
  - `xapk-merger`, `apk-pull --merge`: Java and the SDK build-tools
  - `scrcpy`, `wireshark`, `podman`/`docker`

On macOS:

- On Apple Silicon, create AVDs from **arm64-v8a** system images; x86_64 images don't boot there.
- `androidcontainer` is Linux-only: Google's emulator container needs `/dev/kvm`, which
  Docker Desktop and podman machine don't provide on macOS. Use `launch-emulator <AVD>` instead.
- `launch-emulator-wireshark` finds Wireshark in `/Applications` (or `~/Applications`)
  when `wireshark` isn't on your PATH.

### How the CA injection works

Since Android 14, system CAs come from the Conscrypt APEX module
(`/apex/com.android.conscrypt/cacerts`), and each process sees its own mount namespace.
So remounting `/system` no longer works.
[`device/inject_ca.sh`](modules/android/device/inject_ca.sh)
instead copies the current CA store plus your certificate onto a tmpfs, then bind-mounts
that tmpfs over the APEX directory inside every mount namespace, including zygote's,
so apps launched afterwards trust the CA too. On older Android versions it only replaces
`/system/etc/security/cacerts`. Nothing is written to the system partition, and a reboot
reverts everything. The technique comes from
[HTTP Toolkit](https://httptoolkit.com/blog/android-14-install-system-ca-certificate/).
The `<hash>.0` file Android expects is generated from your ZAP certificate on every run.

### SSL unpinning

A system CA is enough for most apps, but not for those that pin their certificates.
`frida-server --ssl-unpinning <PKG>` handles those on rooted devices and emulators. It
loads these scripts from HTTP Toolkit's
[frida-interception-and-unpinning](https://github.com/httptoolkit/frida-interception-and-unpinning),
with your ZAP CA and proxy filled into their `config.js`:

| Script | Effect |
| --- | --- |
| `native-tls-hook.js` | Native BoringSSL clients trust the ZAP CA |
| `android/android-proxy-override.js` | The app uses the proxy, even if it ignores the system setting |
| `android/android-system-certificate-injection.js` | Java trust stores trust the ZAP CA |
| `android/android-certificate-unpinning.js` | Disables known pinning (OkHttp, TrustKit, Conscrypt, ...) |
| `android/android-certificate-unpinning-fallback.js` | Patches unknown pinning after its first failure |

The proxy is the one `launch-emulator` sets: `10.0.2.2:$RE_ZAP_PORT` on emulators, and
`127.0.0.1:$RE_ZAP_PORT` over `adb reverse` on other devices. The scripts are
AGPL-licensed, so they're downloaded on first use instead of being part of this repo.
`RE_FRIDA_UNPIN_SCRIPTS` changes the list (for example to add
`android/android-disable-root-detection.js`), and `RE_FRIDA_UNPIN_REF` pins a commit or
tag instead of `main`.

On a phone without root, `apk-patch` is the alternative: it only covers pinning
declared in the app's network security config, not pinning in code.

### Settings

Put these in `local/android.sh`:

| Variable | Default |
| --- | --- |
| `ANDROID_HOME` | the SDK in the default Android Studio location |
| `ANDROID_NDK_HOME` | the newest NDK in `$ANDROID_HOME/ndk` |
| `RE_ZAP_SNAPSHOT` | `zap-ready` |
| `RE_CONTAINER_ENGINE` | `podman`, falling back to `docker` |
| `RE_ANDROID_CONTAINER_IMAGE` | `us-docker.pkg.dev/android-emulator-268719/images/30-google-x64` |
| `APKEDITOR_JAR` | `apkeditor` on PATH, else downloaded to `~/.local/share/re-extended-shell/apkeditor/` |
| `JADX` / `JADX_GUI` | `jadx` / `jadx-gui` (the command `apk-decompile` runs and suggests; may carry arguments, e.g. `flatpak run com.github.skylot.jadx`) |
| `RE_FRIDA_UNPIN_SCRIPTS` | the five scripts above |
| `RE_FRIDA_UNPIN_REF` | `main` |

frida-server builds and the unpinning scripts are cached in
`~/.local/share/re-extended-shell/frida/`, the APKEditor jar in
`~/.local/share/re-extended-shell/apkeditor/`.

### Notes

- `launch-emulator` on an AVD without a `zap-ready` snapshot does a **wiped boot**,
  which erases that AVD's user data, then saves the snapshot.
- `adb shell settings put global http_proxy` persists across reboots. On an emulator
  this is what you want. On a phone, run `release-device` when you're done.
- `apk-patch` and `xapk-merger` re-sign the app with a different key, so uninstall the
  original before installing their output. Apps that check their own signature notice.

## Layout and customisation

```
re_extended_shell_main  the one file your rc sources; loads every module
modules/
  core/                 shared by every module, always loaded first
    lib.sh                helpers for every module's commands
    bin/re-doctor
    ...
  android/              one folder per module, with any of:
    bin/                  its commands (standalone bash scripts, put on your PATH)
    lib.sh                helpers for those commands
    env.sh                environment variables
    paths.sh              PATH entries
    functions.sh          shell functions that must run inside your shell
    aliases.sh            aliases
    completions.bash      tab completion (interactive shells only)
    completions.zsh
    doctor.sh             re-doctor checks
    purge.sh              what ./uninstall --purge deletes
    local.example.sh      template for local/<module>.sh
    device/               (android) files that run on the device
local/                  YOUR files (git-ignored), see below
local.example/          templates for local/ (the installer copies them)
lib/rc.sh               shell rc handling for install and uninstall
certs/                  your ZAP root CA (git-ignored)
```

The modules load one kind of file at a time, `core` first and the others
alphabetically, with your `local/` files in between:

1. **env**: `modules/core/env.sh`, `local/env.sh`, then for each module
   `local/<module>.sh` followed by `modules/<module>/env.sh`
2. **paths**: each module's `paths.sh` and `bin/`, then `local/paths.sh`
3. **functions**: each module's `functions.sh`, then `local/functions.sh`
4. **aliases**: each module's `aliases.sh`, then `local/aliases.sh`
5. **completions**: each module's `completions.bash`/`.zsh`, then `local/completions.sh`

So a module's settings go in `local/<module>.sh` (`local/android.sh`), where they're
set before the module reads them, and everything personal (extra PATH entries, your own
aliases, shell functions) goes in the matching `local/` file. `git pull` never
conflicts with any of it. Files in `modules/` and `local/` are sourced by both bash and
zsh, so keep them portable or check `$BASH_VERSION` / `$ZSH_VERSION`. The commands in
`bin/` are separate bash scripts, so they behave the same whichever shell you use.

If you change the code, keep it working on both systems: bash 3.2 (no `mapfile`,
`declare -A` or `${var,,}`) and BSD tools as well as GNU ones (no `readlink -f`,
`sed -i`, `grep -P`, `ss` or `/proc` without a fallback). `modules/core/lib.sh` has
helpers for the OS-specific parts, e.g. `re_port_listening` and `re_proc_has_arg`.

## Adding a module

A module is a folder in `modules/`, picked up automatically. Every file in it is
optional. For a module called `ios`:

| File | Purpose |
| --- | --- |
| `bin/<command>` | Each command, a bash script that sources `../lib.sh`. Copy the first lines of an existing command to get the self-locating `source` line. |
| `lib.sh` | Helpers and settings defaults for the module's commands. Sources `../core/lib.sh` first. Put downloads and caches under `$RE_DATA_DIR/ios/`. |
| `env.sh`, `paths.sh` | Environment and PATH for your interactive shell: SDK detection, `re_path_append` for its tools, and a comment listing its settings. |
| `functions.sh`, `aliases.sh` | Shell functions and aliases. |
| `completions.bash`, `completions.zsh` | Tab completion. `_re_reply_words`, `_re_reply_files` and `_re_reply_dirs` from `core/completions.bash` are available. |
| `doctor.sh` | Checks for `re-doctor`, with its `doc_ok`, `doc_warn`, `doc_fail`, `doc_info` and `doc_tool` helpers. |
| `purge.sh` | Calls `re_purge <path> [label]` for each file or folder its commands leave outside the repo (except under `$RE_DATA_DIR`, which core already covers). |
| `local.example.sh` | Commented examples of its settings, copied to `local/ios.sh` by `./install`. |
| `README.md` (the main one) | A section with the module's commands, requirements and settings, plus a line under **Modules**. |

## Notes

- Only use this on devices, apps and systems you're authorised to test.

## License

[MIT](LICENSE)

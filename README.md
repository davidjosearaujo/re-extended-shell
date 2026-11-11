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
- [Binary](#binary): a first look at native executables and libraries (ELF, Mach-O, PE).
- [Core](#core): what every module shares, `re-doctor`, which checks your setup, and
  `re-extended-shell`, which shows everything that's installed.

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
It also fills `local/` with commented templates for your settings (see
[Configuration](#configuration)), without touching files that are already there.
Running it again is safe: it updates that line in place, for example after you move
the repo.

`./uninstall` removes the hook and lists what the commands created outside the repo.
`./uninstall --purge` also deletes those (downloads, caches, the `zap-ready` snapshots
of your AVDs). Neither touches the repo itself, so delete it afterwards to remove your
`local/` settings and `certs/` too.

Then export ZAP's root CA certificate to `certs/zap_root_ca.cer`, either from
*Tools → Options → Network → Server Certificates → Save*, or with
`zap.sh -cmd -certpubdump certs/zap_root_ca.cer`. PEM and DER both work. Each module
converts it to whatever format its targets expect.

Finally, run `re-doctor` to check that everything is in place, and
`re-extended-shell` to see everything it installed.

### Using the commands

Every command works the same way, so once you know one you know them all:

- `<command> --help` shows its usage, options, the settings it reads (with their
  current value) and examples. `re-extended-shell --commands` lists every command.
- A device is picked with `-s SERIAL` and a running emulator with `-n AVD_NAME`; with a
  single device connected, neither is needed.
- `-o` sets where output goes, and nothing is overwritten without `-f`.
- Errors start with `Error:`, warnings with `Warning:`, and both go to stderr. A
  mistyped option says so and points to `--help`.

## Configuration

Everything works without any configuration. When you want to change something, use
the `local/` folder in the repo. It is git-ignored, so `git pull` never touches it.

**The one rule: don't edit files in `modules/`. Put your changes in `local/`.** Files
in `modules/` are the tool's code and get replaced by updates; a change there will
conflict the next time you pull.

### Change a setting (environment variables)

1. Open `local/env.sh`. `./install` created it for you from
   [local.example/env.sh](local.example/env.sh), which lists every setting as a
   commented example (ZAP port and certificate, `JAVA_HOME`, the Android SDK, jadx,
   and so on).
2. Remove the `#` in front of the line you want and set your value. Keep the
   `export`, because the commands run as separate scripts and only see exported
   variables:

   ```sh
   export ANDROID_HOME="$HOME/sdk/android"
   export RE_ZAP_PORT=8080
   ```

3. Open a new terminal (or run `source ~/.bashrc` / `source ~/.zshrc`). The file is read
   when the shell starts.
4. Run `re-doctor` to check it.

Each setting, with its default, is listed in the section of the module that uses it
([Core](#core), [Android](#android)). `local/env.sh` loads before the modules, so
what you set there is what they see.

### Add your own PATH entries, aliases, functions or completions

The installer creates one file for each, with commented examples:

| File | Put in it |
| --- | --- |
| `local/paths.sh` | extra PATH entries, e.g. `re_path_append "$HOME/tools/bin"` |
| `local/aliases.sh` | your aliases |
| `local/functions.sh` | shell functions that must run inside your shell |
| `local/completions.sh` | tab completion (interactive shells only) |

These files are sourced by both bash and zsh, so keep them portable or check
`$BASH_VERSION` / `$ZSH_VERSION`.

### After `git pull`

You don't need to re-run `./install`. The installer only adds the hook to your rc file
and creates the `local/` files that are missing; it never changes one that exists.
That also means a new setting added by an update does not appear in your `local/env.sh`.
To see what's new, look at [local.example/env.sh](local.example/env.sh) or the settings
table in the module's section, and copy what you want. To start over from the
template, delete your `local/env.sh` and run `./install`.

## Core

| Command | What it does |
| --- | --- |
| `re-doctor [MODULE...]` | Checks the shell hook and PATH, the ZAP certificate (format, expiry) and whether ZAP is listening, then each module's tools, emulators and connected devices, and says how to fix what's missing. Read-only. Exits non-zero if something required is missing. |
| `re-extended-shell` | Shows what's installed: the modules, every command with what it does, the settings with their value and where it comes from (`local/env.sh`, your environment, detected, or the default), the PATH entries the modules add, your aliases and functions, and the downloads and caches. `--modules`, `--commands`, `--envs`, `--paths`, `--aliases`, `--functions` and `--data` show one section each (combine them freely), `-m MODULE` narrows it to a module, `--version` prints the version. It flags what this shell is missing, e.g. a setting changed in `local/env.sh` since the shell started. |

Settings shared by every module (set them in `local/env.sh`, see [Configuration](#configuration)):

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
| `launch-emulator -d [-s SERIAL]` | Same setup on a rooted physical device (userdebug build, or `su` via Magisk/KernelSU). `-s` picks the phone when several are connected (and implies `-d`). Routes the proxy through `adb reverse`, opens [scrcpy](https://github.com/Genymobile/scrcpy) and pushes frida-server the same way. |
| `release-device [-s SERIAL] [--reboot]` | Undoes `launch-emulator -d`: clears the proxy, removes the tunnel, stops frida-server, deletes the pushed files and closes scrcpy. Run it before unplugging the phone, or its network stops working. |
| `kill-emulator [-f] <AVD>` | Shuts an emulator down cleanly by AVD name, killing it only if it won't exit. |
| `reset-emulator [-s SERIAL \| -n AVD]` | Puts a running emulator back to its `zap-ready` snapshot without restarting it (a few seconds), dropping everything since: installed apps, app data, proxy changes. With one emulator running it's picked automatically; with several, name it with `-s` (serial) or `-n` (AVD name). |
| `reset-emulator --save [-s SERIAL \| -n AVD]` | Saves the emulator's current state as the snapshot instead, so you can set up the app under test once and come back to it. `--snapshot NAME` (on either form) uses another snapshot, so you can keep several states. `--save` alone replaces the `zap-ready` one that `launch-emulator` boots from. |
| `device-proxy [-s SERIAL] on\|off\|status` | Turns the ZAP proxy on or off on a running emulator or device without restarting it (for a physical device, the `adb reverse` tunnel too). `release-device` does the same and more when you unplug a phone. |
| `frida-server [-s SERIAL]` | Downloads the frida-server build that matches your `frida --version` and the device's CPU, pushes it and starts it as root. Does nothing if that version already runs. `--push-only` stops after the push, `--stop` kills it, `--refresh` downloads again. |
| `frida-server --ssl-unpinning <PKG>` | Then spawns the app under Frida with [HTTP Toolkit's unpinning scripts](https://github.com/httptoolkit/frida-interception-and-unpinning): it trusts the ZAP CA despite certificate pinning, and is forced through the same proxy `launch-emulator` sets. `-l script.js` loads your own scripts too. |
| `apk-pull [-s SERIAL] <PKG>` | Pulls every APK of an installed app (base + splits) into `./<PKG>-splits/`. With `--merge`, saves a single installable `./<PKG>.apk` instead (merged with `xapk-merger` when the app has splits; `-k/-p/-a` sign it with your own keystore). `-o` sets the output, `-f` replaces an existing one. |
| `apk-decompile <file.apk>` | Decompiles into `./<name>/jadx/` (Java, with [jadx](https://github.com/skylot/jadx)) and `./<name>/apktool/` (smali, manifest and resources, with [apktool](https://apktool.org)), running whichever is installed. |
| `apk-patch <file.apk>` | For phones you can't root: makes the app trust user CAs and the ZAP CA (embedded in the APK), overriding `<pin-set>`s, allows cleartext, sets `debuggable`, then rebuilds and signs it. `-o` sets the output, `-f` replaces an existing one. |
| `apk-info [-s SERIAL] <file.apk \| PKG>` | A static first look at an app, without decompiling it: the components other apps can reach and the permission guarding each (flagging those anyone can get), the URIs its deep links open, `debuggable`/`allowBackup`/cleartext, its network security config (cleartext, user CAs, pins, debug overrides), the permissions it asks for and declares, its signature (debug certificate, Janus), and its code (dex, native libraries, and whether it's Flutter, React Native, Xamarin, Unity, Cordova or Capacitor). Works on a file or on an installed app, by package name. `--all` lists the components that aren't exported too. |
| `app-intent [-s SERIAL] <PKG> [COMPONENT]` | Without a component, lists the app's exported components, numbered. With one (number, full name or `.ShortName`), starts it as another app would: `am start` for an activity, `am startservice`, `am broadcast`, or `content query` on a provider. `--action`, `--data URI` and `-e KEY=VALUE` fill the intent, and arguments after `--` go to `am`/`content`. `--data` alone tries a deep link. It runs as the shell user even when adbd is root, so it's refused where another app would be; `--root` reaches the components that aren't exported. |
| `app-data [-s SERIAL] [--diff DIR] <PKG>` | Copies the app's private storage off a rooted device (`/data/data`, device-encrypted storage, external storage) into `./<PKG>-data/`, then lists its preferences, databases and the lines that look like tokens or passwords. `--diff DIR` compares the copy with an earlier one: preferences and other text files line by line, databases row by row (with `sqlite3`), so you see what an action in the app writes. |
| `applog [-s SERIAL] [--start] <PKG>` | `logcat` for that app's process only. Waits for it to start and follows it across restarts. `--start` (re)launches it; arguments after `--` go to logcat. |
| `launch-emulator-wireshark [-s SERIAL] [-i IFACE]` | Streams `tcpdump` from the device into a local Wireshark window. |
| `xapk-installer [-s SERIAL \| -n AVD] <file.xapk>` | Installs every split in an XAPK/ZIP bundle with `adb install-multiple` and pushes any OBB data. |
| `xapk-merger [options] <file.xapk\|.apks\|dir>` | Merges the splits (of a bundle, or a directory of APKs) into one installable APK with [APKEditor](https://github.com/REAndroid/APKEditor), downloaded on first use. Then zipaligns it and signs it with the debug keystore or your own (`-k`). Like the other commands that write files, it won't replace an existing output without `-f`. `xapk-merger --provision` downloads APKEditor ahead of time, or updates it to the latest release. |
| `androidcontainer` | Runs Google's Android emulator container (podman or docker) and connects adb to it as root. Linux only, it needs KVM. |

Every command takes `-h`/`--help`, and all of them have tab completion in bash and zsh,
including AVD names, device serials and the packages installed on the device.

A typical session with an app that pins its certificates:

```sh
launch-emulator Pixel_8_API_34          # CA injected, proxied through ZAP, frida-server pushed
xapk-installer app.xapk                 # or install it from the Play Store
apk-info com.example.app                # what it exposes, how it treats TLS
frida-server --ssl-unpinning com.example.app
applog com.example.app                  # in another terminal
app-intent com.example.app              # its exported components; start one by number
app-data com.example.app                # what it stores; later: app-data --diff com.example.app-data com.example.app
apk-pull --merge com.example.app && apk-decompile com.example.app.apk
```

### Requirements

- Android SDK platform-tools and emulator, `openssl`. The SDK is found in the default
  Android Studio location; set `ANDROID_HOME` in `local/env.sh` if yours is elsewhere.
- For emulators: a **Google APIs** system image. Google Play images don't allow `adb root`.
- Optional, per command:
  - `frida-server`: [frida-tools](https://frida.re) (`pipx install frida-tools`), plus
    `xz` or `python3` to unpack the download
  - `apk-decompile`: jadx and/or apktool. jadx has no `apt` package (brew,
    flatpak, a release binary or a manual build); if it isn't `jadx` on your
    PATH, point `JADX` (and `JADX_GUI`) at it, arguments included
  - `apk-info`, `app-intent`: `aapt2` from the SDK build-tools (`apk-info` also uses
    `apksigner` for the signature, and `unzip`)
  - `app-data`: a rooted device or emulator; `sqlite3` (in platform-tools) to diff databases
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

Put these in `local/env.sh`:

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

## Binary

Native executables and libraries on Linux, macOS and Windows, with no device involved.

### Commands

| Command | What it does |
| --- | --- |
| `bin-triage <file>` | A first look at an ELF, Mach-O or PE file, in one report: file type, size and hashes (MD5, SHA-1, SHA-256); whole-file entropy, which flags packed or encrypted files; hardening (PIE, NX, RELRO, stack canary, fortify and stripped for ELF; PIE, canary, signed and encrypted for Mach-O; ASLR, DEP and control-flow guard for PE); the libraries it links; the imports that matter (exec, network, memory, anti-debugging); and the URLs, IP addresses, e-mail addresses, paths, keys and password-like strings in its text. `-n` sets the shortest string, `-l` how many lines each list shows. Other files get the generic parts. It only reads the file, it never runs it. |

### Requirements

- `file` and `strings` (binutils; on macOS the Xcode command line tools).
- For the format details: `readelf` for ELF, `objdump` for PE (both from binutils), `otool` and `nm` for Mach-O.
- `python3` for the entropy figure. Anything missing is skipped and named in the report, and `re-doctor` lists it.

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
    device/               (android) files that run on the device
local/                  YOUR files (git-ignored), see below
local.example/          templates for local/ (the installer copies them)
lib/rc.sh               shell rc handling for install and uninstall
certs/                  your ZAP root CA (git-ignored)
```

The modules load one kind of file at a time, `core` first and the others
alphabetically, with your `local/` files in between:

1. **env**: `modules/core/env.sh`, `local/env.sh`, then each module's `env.sh`
2. **paths**: each module's `paths.sh` and `bin/`, then `local/paths.sh`
3. **functions**: each module's `functions.sh`, then `local/functions.sh`
4. **aliases**: each module's `aliases.sh`, then `local/aliases.sh`
5. **completions**: each module's `completions.bash`/`.zsh`, then `local/completions.sh`

Your files go in `local/`, never in `modules/` (see [Configuration](#configuration)).
Files in `modules/` and `local/` are sourced by both bash and zsh, so keep them
portable or check `$BASH_VERSION` / `$ZSH_VERSION`. The commands in `bin/` are
separate bash scripts, so they behave the same whichever shell you use.

If you change the code, keep it working on both systems: bash 3.2 (no `mapfile`,
`declare -A` or `${var,,}`) and BSD tools as well as GNU ones (no `readlink -f`,
`sed -i`, `grep -P`, `ss` or `/proc` without a fallback). `modules/core/lib.sh` has
helpers for the OS-specific parts, e.g. `re_port_listening` and `re_proc_has_arg`.
In a command's option parser, call `re_need_arg "$1" "$#"` before reading `$2`, so a
missing value is an error instead of an endless loop.

## Adding a module

A module is a folder in `modules/`, picked up automatically. Every file in it but
`manifest` is optional. For a module called `ios`:

| File | Purpose |
| --- | --- |
| `manifest` | Required. An `about:` line saying what the module is for, and a `setting: NAME \| default \| what it does \| commands that use it` line per setting its commands read. `re-extended-shell` and every command's `--help` read it. |
| `bin/<command>` | Each command, a bash script that sources `../lib.sh`. Line 2 is a one-line summary (`# Do this to that.`), which `re-extended-shell --commands` shows. Copy the first lines of an existing command to get the self-locating `source` line. |
| `lib.sh` | Helpers and settings defaults for the module's commands. Sources `../core/lib.sh` first. Put downloads and caches under `$RE_DATA_DIR/ios/`. |
| `env.sh`, `paths.sh` | Environment and PATH for your interactive shell: SDK detection and `re_path_append` for its tools. Not for user settings. |
| `functions.sh`, `aliases.sh` | Shell functions and aliases. |
| `completions.bash`, `completions.zsh` | Tab completion. `_re_reply_words`, `_re_reply_files` and `_re_reply_dirs` from `core/completions.bash` are available. |
| `doctor.sh` | Checks for `re-doctor`, with its `doc_ok`, `doc_warn`, `doc_fail`, `doc_info` and `doc_tool` helpers. |
| `purge.sh` | Calls `re_purge <path> [label]` for each file or folder its commands leave outside the repo (except under `$RE_DATA_DIR`, which core already covers). |
| `README.md` (the main one) | A section with the module's commands, requirements and settings, plus a line under **Modules**. |

The commands are one family: they look and behave the same, so whoever knows one
knows them all. A new command must follow these conventions.

**Options**

- Every option has a long form; common ones have a short form too.
- A device is chosen with `-s, --serial SERIAL` and a running emulator by AVD name
  with `-n, --name AVD_NAME`, never by a bare argument. Either can be left out when
  only one device is connected.
- `-o, --output` sets where output goes. A command never replaces an existing output
  unless given `-f, --force`. Signing takes `-k, --keystore`, `-p, --ks-pass`,
  `-a, --alias`. A switch that turns something off is `--no-<thing>`.

**Help**: `usage()` prints these parts, in this order, separated by blank lines:

1. `Usage: <command> ...` (more forms on lines starting with 7 spaces). Option values
   are UPPERCASE (`-o FILE`), required operands in angle brackets (`<file.apk>`),
   alternatives as `[-a | -b]`.
2. A description, flush left, wrapped at 80 columns.
3. Optionally `Actions:`, `Arguments:` or `Output:`, two-space indented lists.
4. `Options:`, one line per option in the order device, output, `-f`, the command's
   own, signing, and last `-h, --help  Show this help`. Descriptions start in one
   column, and so do their continuation lines. Defaults read `(default: X)`.
5. Optionally `Examples:`, as `  command   # what it does`.

`-h|--help) re_help; exit 0 ;;` prints that, then a `Settings:` section built from the
manifests and the footer every command shares.

**Errors and messages** (helpers in `modules/core/lib.sh`)

- `re_die "..."` prints `Error: ...`, `re_warn "..."` prints `Warning: ...`, both on
  stderr and starting lowercase.
- The option loop ends with `-*) re_unknown_option "$1" ;;` and, for arguments it
  doesn't take, `*) re_unexpected_arg "$1" ;;`. Options that take a value check for it
  with `re_need_arg`.
- A command that writes a file or folder calls `re_refuse_existing "$FORCE" PATH` before
  touching it. Signing options go through `re_sign_opt` and `re_check_keystore`.
- A missing operand is `re_usage_error "missing <file.apk>."`: the error, the Usage
  line and a pointer to `--help`.
- Progress lines end with `...`; the last line says what was done and where the result
  is (`Merged APK: ./app_merged.apk`). No message ends with `!`.
- A command that prints a report uses `re_section "Title"`, `re_row Label value` and
  `... | re_list [LIMIT]` (an indented list that ends with "... and N more"), so every
  report has the same layout.
- A command that needs root on a device gets it with `ROOT=$(re_require_root "$SERIAL") || exit 1`
  and runs commands with `re_root_shell`. Commands that read an APK's manifest use
  `re_manifest_records`; awk code that reads `aapt2` output starts with `"$RE_AWK_LIB"`.

## Notes

- Only use this on devices, apps and systems you're authorised to test.

## License

[MIT](LICENSE)

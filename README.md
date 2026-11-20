# RE Extended Shell

Shell tooling for reverse engineering and security testing, for bash and zsh on Linux
and macOS.

It's one place for the commands, environment setup and tab completion that RE work
needs, organised in modules, one per theme. Each module brings its own commands,
environment, PATH entries, aliases and completions, and everything installs and
uninstalls with a single hook in your shell's rc file. Your personal settings live in a
git-ignored `local/` folder, so updates never conflict with them.

**Modules:**

- [Android](#android): emulators and rooted phones, with a proxy's CA injected as a
  system CA on request (Android 14+ included), Frida with SSL unpinning, pulling, decompiling and
  patching APKs, split APK/XAPK handling, per-app logs and live traffic capture.
- [Binary](#binary): a first look at native executables and libraries (ELF, Mach-O, PE),
  the symbols they export, the crypto built into them, and the protobuf schemas too.
- [Crypto](#crypto): every digest of a file, what a certificate says and pins to, and
  what's inside a JWT.
- [Core](#core): what every module shares, `re-doctor`, which checks your setup, and
  `re-extended-shell`, which shows everything that's installed.

More modules will follow. See [Adding a module](#adding-a-module), or go straight to
[modules/README.md](modules/README.md).

## Contents

- [Requirements](#requirements)
- [Install](#install)
  - [Using the commands](#using-the-commands)
- [Configuration](#configuration)
  - [Change a setting (environment variables)](#change-a-setting-environment-variables)
  - [Add your own PATH entries, aliases, functions or completions](#add-your-own-path-entries-aliases-functions-or-completions)
  - [After `git pull`](#after-git-pull)
- [Core](#core)
- [Android](#android)
  - [Commands](#commands)
  - [Requirements](#requirements-1)
  - [How the CA injection works](#how-the-ca-injection-works)
  - [SSL unpinning](#ssl-unpinning)
  - [Settings](#settings)
  - [Notes](#notes)
- [Binary](#binary)
  - [Commands](#commands-1)
  - [Requirements](#requirements-2)
- [Crypto](#crypto)
  - [Commands](#commands-2)
  - [Requirements](#requirements-3)
- [Layout and customisation](#layout-and-customisation)
- [Adding a module](#adding-a-module)
- [Notes](#notes-1)
- [License](#license)

## Requirements

- Linux or macOS. The commands run on any bash from 3.2 up, so macOS's built-in
  `/bin/bash` is enough; your own shell can be bash or zsh
- An intercepting proxy to read the traffic: [ZAP](https://www.zaproxy.org/),
  [Burp](https://portswigger.net/burp), [mitmproxy](https://mitmproxy.org/), Charles,
  HTTP Toolkit... Any of them works: the commands only need its port and its root CA.
  `device-proxy` and `frida-server --ssl-unpinning` expect it on `127.0.0.1:9090`
  (change with `RE_PROXY_PORT`); `launch-emulator --proxy` takes the port you give it.
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
`./uninstall --purge` also deletes those (downloads, caches, the `re-ready` snapshots
of your AVDs). Neither touches the repo itself, so delete it afterwards to remove your
`local/` settings and `certs/` too.

For `frida-server --ssl-unpinning` and `apk-patch`, export your intercepting proxy's
root CA certificate to `certs/proxy_ca.cer` (or set `RE_PROXY_CERT`). PEM and DER both
work; each module converts it to whatever format its targets expect. For example:

| Proxy | Where its CA comes from |
| --- | --- |
| ZAP | *Tools → Options → Network → Server Certificates → Save*, or `zap.sh -cmd -certpubdump certs/proxy_ca.cer` |
| Burp | *Proxy → Proxy settings → Import / export CA certificate* (DER) |
| mitmproxy | `~/.mitmproxy/mitmproxy-ca-cert.pem` |

Finally, run `re-doctor` to check that everything is in place, and
`re-extended-shell` to see everything it installed.

### Using the commands

Every command works the same way, so once you know one you know them all:

- `<command> --help` shows its usage, options, the settings it reads (with their
  current value) and examples. `re-extended-shell --commands` lists every command.
- A device is picked with `-s SERIAL` and a running emulator with `-n AVD_NAME`; with a
  single device connected, neither is needed. A running emulator answers to both, so
  either flag takes either identifier and `-s` accepts an AVD name; what can only be an
  emulator (snapshots, `kill-emulator`) says so when given a phone, instead of failing
  obscurely.
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
   commented example (proxy port and certificate, `JAVA_HOME`, the Android SDK, jadx,
   and so on).
2. Remove the `#` in front of the line you want and set your value. Keep the
   `export`, because the commands run as separate scripts and only see exported
   variables:

   ```sh
   export ANDROID_HOME="$HOME/sdk/android"
   export RE_PROXY_PORT=8080
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
| `re-doctor [MODULE...]` | Checks the shell hook and PATH, the proxy's CA certificate (format, expiry, if there is one) and whether something listens on the proxy port, then each module's tools, emulators and connected devices, and says how to fix what's missing. Read-only. Exits non-zero if something required is missing. |
| `re-extended-shell` | Shows what's installed: the modules, every command with what it does, the settings with their value and where it comes from (`local/env.sh`, your environment, detected, or the default), the PATH entries the modules add, your aliases and functions, and the downloads and caches. `--modules`, `--commands`, `--envs`, `--paths`, `--aliases`, `--functions` and `--data` show one section each (combine them freely), `-m MODULE` narrows it to a module, `--version` prints the version. It flags what this shell is missing, e.g. a setting changed in `local/env.sh` since the shell started. |

Settings shared by every module (set them in `local/env.sh`, see [Configuration](#configuration)):

| Variable | Default |
| --- | --- |
| `RE_PROXY_PORT` | `9090` |
| `RE_PROXY_CERT` | `certs/proxy_ca.cer` |
| `JAVA_HOME` | the JDK behind `java` on PATH, else a Homebrew `openjdk` (its `bin/` is added to PATH if no `java` is there yet) |

`RE_ZAP_PORT`, `RE_ZAP_CERT` and `certs/zap_root_ca.cer`, the names older versions used,
still work when the new ones aren't set.

## Android

### Commands

| Command | What it does |
| --- | --- |
| `launch-emulator <AVD>` | Starts the AVD as it is: no wipe, its state isn't saved on exit, nothing is changed on it. If it's already running, uses that emulator. Everything else is a flag: `--read-only` keeps nothing from the session (disk included); `--push-frida-server` pushes the frida-server build that matches your `frida --version`, and `--start-frida-server` starts it too; `--proxy`/`--ca` below. Root is only taken when a flag needs it. |
| `launch-emulator --snapshot [NAME] <AVD>` | Boots from snapshot `NAME` (default `re-ready`), so boots take seconds. When the AVD has no such snapshot yet, boots it as it is, sets up what the other flags ask for and saves it under that name. `--clean` does a wiped boot first (erasing the AVD's user data), and replaces the snapshot if there is one; it's the only flag that wipes. frida-server goes into the snapshot; the CA and proxy never do. |
| `launch-emulator --proxy PORT --ca FILE <AVD>` | Also injects `FILE` (your proxy's root CA, PEM or DER) as a system CA and sets the global HTTP proxy to `PORT` on this machine, e.g. `--proxy 8080 --ca ~/burp-ca.der` for Burp. The two go together. |
| `launch-emulator -d [-s SERIAL]` | The same on a physical device, with `--proxy`/`--ca` and the frida-server flags (those need root: a userdebug build, or `su` via Magisk/KernelSU). `-s` picks the phone when several are connected (and implies `-d`); an `emulator-NNNN` serial there stands for the AVD that emulator runs, so it stays on the emulator path. Routes the proxy through `adb reverse`, and opens [scrcpy](https://github.com/Genymobile/scrcpy). |
| `release-device [-s SERIAL] [--reboot]` | Undoes `launch-emulator -d`: clears the proxy and the `adb reverse` tunnel it goes through (other tunnels are left alone), stops frida-server, deletes the pushed files and closes scrcpy. Run it before unplugging a phone that has a proxy set, or its network stops working. |
| `kill-emulator [-f] <AVD\|SERIAL>` | Shuts an emulator down cleanly, by AVD name or by its `emulator-NNNN` serial, killing it only if it won't exit. |
| `reset-emulator [-s SERIAL \| -n AVD]` | Puts a running emulator back to its `re-ready` snapshot (the one `launch-emulator --snapshot` saves) without restarting it (a few seconds), dropping everything since: installed apps, app data, the proxy and CA `launch-emulator --proxy --ca` set up. With one emulator running it's picked automatically; with several, name it with `-s` (serial) or `-n` (AVD name) — either flag takes either identifier. |
| `reset-emulator --save [-s SERIAL \| -n AVD]` | Saves the emulator's current state as the snapshot instead, so you can set up the app under test once and come back to it. `--snapshot NAME` (on either form) uses another snapshot, so you can keep several states. `--save` alone replaces the `re-ready` one that `launch-emulator --snapshot` boots from. |
| `device-proxy [-s SERIAL \| -n AVD] on\|off\|status` | Points the global HTTP proxy at your proxy's port (`RE_PROXY_PORT`), or turns it off, on a running emulator or device without restarting it (for a physical device, the `adb reverse` tunnel too). `off` clears any global HTTP proxy. `release-device` does the same and more when you unplug a phone. |
| `frida-server [-s SERIAL \| -n AVD]` | Downloads the frida-server build that matches your `frida --version` and the device's CPU, pushes it and starts it as root. Does nothing if that version already runs. `--push-only` stops after the push, `--stop` kills it, `--refresh` downloads again. |
| `frida-server --ssl-unpinning <PKG>` | Then spawns the app under Frida with [HTTP Toolkit's unpinning scripts](https://github.com/httptoolkit/frida-interception-and-unpinning): it trusts your proxy's CA (`RE_PROXY_CERT`) despite certificate pinning, and is forced through your proxy (`RE_PROXY_PORT`). `-l script.js` loads your own scripts too. |
| `apk-pull [-s SERIAL \| -n AVD] <PKG>` | Pulls every APK of an installed app (base + splits) into `./<PKG>-splits/`. With `--merge`, saves a single installable `./<PKG>.apk` instead (merged with `xapk-merger` when the app has splits; `-k/-p/-a` sign it with your own keystore). `-o` sets the output, `-f` replaces an existing one. |
| `apk-decompile <file.apk>` | Decompiles into `./<name>/jadx/` (Java, with [jadx](https://github.com/skylot/jadx)) and `./<name>/apktool/` (smali, manifest and resources, with [apktool](https://apktool.org)), running whichever is installed. |
| `apk-patch <file.apk>` | For phones you can't root: makes the app trust user CAs and your proxy's CA (`RE_PROXY_CERT`, embedded in the APK), overriding `<pin-set>`s, allows cleartext, sets `debuggable`, then rebuilds and signs it. `-o` sets the output, `-f` replaces an existing one. |
| `apk-info [-s SERIAL \| -n AVD] <file.apk \| PKG>` | A static first look at an app, without decompiling it: the components other apps can reach and the permission guarding each (flagging those anyone can get), the URIs its deep links open, `debuggable`/`allowBackup`/cleartext, its network security config (cleartext, user CAs, pins, debug overrides), the permissions it asks for and declares, its signature (debug certificate, Janus), the framework it's built with — Flutter, React Native (and Hermes), Unity (IL2CPP or Mono), Xamarin/.NET, Cocos2d-x, Unreal, Godot, NativeScript, Qt, Python, Capacitor or Cordova — with the evidence found, where the real code lives and the tool to get at it, and its code (dex and native libraries). The framework is matched on the manifest's engine class names (e.g. `org.cocos2dx.*`, `com.unity3d.player.*`) as well as asset markers and native libraries, so it's recognised even when the engine library has been renamed or sits in a config split. Works on a file or on an installed app, by package name. `--all` lists the components that aren't exported too. |
| `app-intent [-s SERIAL \| -n AVD] <PKG> [COMPONENT]` | Without a component, lists the app's exported components, numbered. With one (number, full name or `.ShortName`), starts it as another app would: `am start` for an activity, `am startservice`, `am broadcast`, or `content query` on a provider. `--action`, `--data URI` and `-e KEY=VALUE` fill the intent, and arguments after `--` go to `am`/`content`. `--data` alone tries a deep link. It runs as the shell user even when adbd is root, so it's refused where another app would be; `--root` reaches the components that aren't exported. |
| `app-data [-s SERIAL \| -n AVD] [--diff DIR] <PKG>` | Copies the app's private storage off a rooted device (`/data/data`, device-encrypted storage, external storage) into `./<PKG>-data/`, then lists its preferences, databases and the keys, tokens and password-like lines in them (with `stringx`, keys in databases and binary files too). `--diff DIR` compares the copy with an earlier one: preferences and other text files line by line, databases row by row (with `sqlite3`), so you see what an action in the app writes. |
| `app-reset [-s SERIAL \| -n AVD] <PKG>` | Puts one app back to a fresh install without restoring a snapshot or reinstalling: force-stops it, clears its data and caches (as *Clear storage* does) and revokes the runtime permissions it was granted, so it asks again. `--grant-all` grants every runtime permission it asks for instead, so no prompt gets in the way of testing; `--keep-data` only resets permissions, `--keep-perms` leaves them alone, `--start` launches it afterwards. No root needed, so it works on phones too. |
| `app-memdump [-s SERIAL \| -n AVD] [-g PATTERN] <PKG>` | Copies a running app's readable memory off a rooted device over Frida (starting `frida-server` if needed) into `./<PKG>-memdump/`: one file per memory range, named by its base address, and `strings.txt` with every string in them (ASCII and UTF-16). Then lists the keys, tokens and password-like strings it holds, which often never reach its storage, and with `-g` the strings matching a pattern (a value you typed in, say). Get the app to the state you want first (logged in, after an action). Memory backed by system files is left out unless `--all`; `--process` picks another of its processes. |
| `applog [-s SERIAL \| -n AVD] [--start] <PKG>` | `logcat` for that app's process only. Waits for it to start and follows it across restarts. `--start` (re)launches it; arguments after `--` go to logcat. |
| `launch-emulator-wireshark [-s SERIAL \| -n AVD] [-i IFACE]` | Streams `tcpdump` from the device into a local Wireshark window. |
| `xapk-installer [-s SERIAL \| -n AVD] <file.xapk>` | Installs every split in an XAPK/ZIP bundle with `adb install-multiple` and pushes any OBB data. |
| `xapk-merger [options] <file.xapk\|.apks\|dir>` | Merges the splits (of a bundle, or a directory of APKs) into one installable APK with [APKEditor](https://github.com/REAndroid/APKEditor), downloaded on first use. Then zipaligns it and signs it with the debug keystore or your own (`-k`). Like the other commands that write files, it won't replace an existing output without `-f`. `xapk-merger --provision` downloads APKEditor ahead of time, or updates it to the latest release. |
| `androidcontainer` | Runs Google's Android emulator container (podman or docker) and connects adb to it as root. Linux only, it needs KVM. |

Every command takes `-h`/`--help`, and all of them have tab completion in bash and zsh,
including AVD names, device serials and the packages installed on the device.

A typical session with an app that pins its certificates:

```sh
launch-emulator --snapshot --push-frida-server --proxy 8080 --ca certs/proxy_ca.cer Pixel_8_API_34
                                        # from a snapshot, your proxy's CA injected, traffic sent to it
xapk-installer app.xapk                 # or install it from the Play Store
apk-info com.example.app                # what it exposes, how it treats TLS
frida-server --ssl-unpinning com.example.app
applog com.example.app                  # in another terminal
app-intent com.example.app              # its exported components; start one by number
app-data com.example.app                # what it stores; later: app-data --diff com.example.app-data com.example.app
app-memdump com.example.app             # what it only holds in memory, once logged in
app-reset --grant-all com.example.app   # start again from a fresh install
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
  - `app-data`: a rooted device or emulator; `sqlite3` (in platform-tools) to diff databases;
    [`stringx`](https://codeberg.org/davidjosearaujo/stringx) to find keys in databases
    and binary files
  - `app-memdump`: a rooted device or emulator and frida-tools, whose Python bindings it
    uses (found through the `frida` command, so a `pipx` install works); `stringx` for
    the UTF-16 strings and its key patterns, else binutils `strings`
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
It runs when you pass `launch-emulator --ca`. The `<hash>.0` file Android expects is
generated from that certificate on every run.

### SSL unpinning

A system CA is enough for most apps, but not for those that pin their certificates.
`frida-server --ssl-unpinning <PKG>` handles those on rooted devices and emulators. It
loads these scripts from HTTP Toolkit's
[frida-interception-and-unpinning](https://github.com/httptoolkit/frida-interception-and-unpinning),
with your proxy's CA and address filled into their `config.js`:

| Script | Effect |
| --- | --- |
| `native-tls-hook.js` | Native BoringSSL clients trust your proxy's CA |
| `android/android-proxy-override.js` | The app uses the proxy, even if it ignores the system setting |
| `android/android-system-certificate-injection.js` | Java trust stores trust your proxy's CA |
| `android/android-certificate-unpinning.js` | Disables known pinning (OkHttp, TrustKit, Conscrypt, ...) |
| `android/android-certificate-unpinning-fallback.js` | Patches unknown pinning after its first failure |

The proxy is yours, on this machine: `10.0.2.2:$RE_PROXY_PORT` on emulators, and
`127.0.0.1:$RE_PROXY_PORT` over `adb reverse` on other devices. The scripts are
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
| `RE_EMULATOR_SNAPSHOT` | `re-ready` |
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

- Only `launch-emulator --clean` does a **wiped boot**, which erases that AVD's user
  data. Everything else starts the AVD as it is.
- The global HTTP proxy (`launch-emulator --proxy`, `device-proxy on`) persists across
  reboots. On a phone, run `release-device` (or `device-proxy off`) when you're done.
- Snapshots called `zap-ready`, saved by older versions, have ZAP's CA and proxy in
  them and aren't used any more. `launch-emulator --snapshot` points them out; delete them
  from the AVD's `snapshots/` folder.
- `apk-patch` and `xapk-merger` re-sign the app with a different key, so uninstall the
  original before installing their output. Apps that check their own signature notice.

## Binary

Native executables and libraries on Linux, macOS and Windows, with no device involved.

### Commands

| Command | What it does |
| --- | --- |
| `bin-triage <file>` | A first look at an ELF, Mach-O or PE file, in one report: file type, size and hashes (MD5, SHA-1, SHA-256); whole-file entropy, which flags packed or encrypted files; hardening (PIE, NX, RELRO, stack canary, fortify and stripped for ELF; PIE, canary, signed and encrypted for Mach-O; ASLR, DEP and control-flow guard for PE); the libraries it links; the imports that matter (exec, network, memory, anti-debugging); the URLs, IP addresses, e-mail addresses, paths, keys and password-like strings in its text; and, with `stringx` (see Requirements below), what's hidden in Base64, hex, gzip or zlib data. `-n` sets the shortest string, `-l` how many lines each list shows, `--xor` also tries every single-byte XOR key (slow), and `--decode` decodes files over 32 MiB too. Other files get the generic parts. It only reads the file, it never runs it. |
| `proto-extract <file \| dir>...` | Recovers the `.proto` files an app was built with, so its protobuf traffic can be decoded with field names instead of numbers. Code generated for the full protobuf runtime embeds each `.proto` file as a descriptor; this finds them in native libraries and executables (C++, Go, Rust, ...), in dex files (Java), in Python modules, and inside APK, JAR and other zip archives, and writes them back as `.proto` source into `./<name>-protos/` under their own paths. `--all` keeps the standard `google/protobuf` ones. Then: `protoc --decode=pkg.Message -I <name>-protos file.proto < body.bin`. Apps built with protobuf-lite (most Android apps) carry no descriptors. |
| `so-exports <file>...` | The symbols a shared library or executable exports, demangled, so you know what can be hooked by name: its JNI entry points first (`Java_*` and `JNI_OnLoad`, what an Android app calls into), then the rest, and the module name a Frida hook addresses it by (an ELF `SONAME`, else the file name). `-g PATTERN` filters them (`-g 'crypt\|sign\|key'`), `-l` sets how many lines each list shows (`--all` for all of them), `--imports` also lists what it needs from other libraries. Ends with an `Interceptor.attach` line ready to paste (`frida-hook` writes a whole script). It only reads the file, it never runs it. |
| `frida-hook <file.so> [SYMBOL...]` | Writes a Frida script (`./<library>-hook.js`, or `-o FILE`, `-o -` for stdout) that hooks a library's exported functions and logs every call: its arguments, as pointers plus the text when one points to a readable string, and its return value. Hooks the JNI entry points by default, labelled with the Java method each one implements (`com.example.Crypto.encrypt`); `-g PATTERN` or `SYMBOL` names (mangled or demangled) pick other exports, data symbols never. The script waits for the library to be loaded, so it works on an app spawned under Frida, and runs on Frida 16 and 17. `--args N` sets how many arguments to show, `--backtrace` prints where each call came from. Load it with `frida -U -f <PKG> -l FILE` or `frida-server --ssl-unpinning <PKG> -l FILE`. It only reads the file, it never runs it. |
| `crypto-find <file \| dir>...` | Finds the crypto algorithms built into a binary by the constants they carry, whatever the code around them looks like: AES by its S-box, the SHA and MD5 families by their round tables, Blowfish by the digits of pi, ChaCha by its `expand 32-byte k` string, SM4, CRC-32, and base64 alphabets, **including the shuffled custom ones apps use to hide data**. The table constants are found in either byte order. Reads native binaries, dex files, and the members of an APK or other zip (`python3`, with its own zip reader). `--min-confidence low\|medium\|high` filters out the weaker hits. RC4 and plain XOR have no constants, so their absence says nothing, and a constant isn't proof the code reaches it — but it tells you what to look for. It only reads the file, it never runs it. |
| `crypto-libs <file \| dir>...` | Names the crypto and TLS libraries compiled or bundled into a binary, from the version banners and package names in their strings: OpenSSL and its forks (BoringSSL, LibreSSL), mbedTLS, wolfSSL, GnuTLS, NSS, libsodium, Botan, Crypto++, and the Java ones in a dex (Bouncy Castle, Conscrypt, Tink, SQLCipher), with the version where the strings carry one — so you can tell an app's TLS stack and whether it's a long-outdated build. Reads native binaries, dex files, and the `.so`/`.dex`/`.jar` members of an APK (with `unzip`). It only reads the file, it never runs it. |

### Requirements

- `file`.
- `python3` for the entropy figure, `proto-extract` and `crypto-find` (standard library
  only; `crypto-find` reads zip archives with Python's own reader, no `unzip` needed).
- `unzip` for `crypto-libs` to look inside an APK or other zip (it reads a plain file
  without it).
- [`stringx`](https://codeberg.org/davidjosearaujo/stringx) to read the strings: ASCII
  and UTF-16 (which binutils `strings` misses, and Windows binaries are full of), its
  secret patterns, and decoding. It's a single binary, from
  [its releases](https://codeberg.org/davidjosearaujo/stringx/releases); put it on your
  PATH. Without it, `bin-triage` falls back to `strings` (binutils; on macOS the Xcode
  command line tools), ASCII only and without the decoded section.
- For the format details: `readelf` for ELF, `objdump` for PE (both from binutils), `otool` and `nm` for Mach-O.
- `so-exports` and `frida-hook` read the symbols with `nm`, falling back to `readelf` or
  `objdump`, and demangle C++ names with `c++filt` when it's installed (all from binutils).
- Anything missing is skipped and named in the report, and `re-doctor` lists it.

## Crypto

Hashes, certificates and tokens: the things you check by hand in the middle of
everything else, with no device involved.

### Commands

| Command | What it does |
| --- | --- |
| `file-hash <file>...` | Every digest of a file this machine can compute, in one report: MD5, SHA-1, SHA-224, SHA-256, SHA-384, SHA-512, SHA3-256, SHA3-512, BLAKE2b and the CRC-32 (zlib's, the one zip tools show), with whichever tools are installed and all at once, so a big file takes as long as its slowest digest; plus a fuzzy hash (`ssdeep`, `tlsh`) which, unlike the rest, stays similar between two versions of a file. `--algo` picks the algorithms, `--vt` adds the VirusTotal URL for the SHA-256 (nothing is uploaded). An algorithm no tool here can do is skipped and named. |
| `file-hash --check SUM <file>` | Compares a hash from a vendor page, a report or VirusTotal with every digest of the file and says whether it matches, so you don't have to know which algorithm you were given. Exits non-zero when nothing matches. |
| `file-hash [--dups] -r <file \| dir>...` | One `DIGEST  path` line per file (SHA-256, or the first of `--algo`), walking directories. `--dups` instead groups the files that share a digest: the same library under several ABIs, or the splits that didn't change between two versions of an app. |
| `cert-info [<file \| host[:port]>]` | What a certificate says: subject and issuer (and whether it's self-signed), validity with how long that is from now, key, signature, whether it's a CA, the names it covers, its SHA-256 and SHA-1 fingerprints, its **SPKI pin** (the `<pin digest="SHA-256">` value an app's network security config carries, so you can compare what the app expects with what your proxy or the real server presents) and the **`<subject_hash_old>.0`** name it takes in Android's system store. Reads PEM, DER and bundles; given a host it connects and reports the whole chain the server sends, with the TLS version and cipher. With no argument it reads your proxy's CA (`RE_PROXY_CERT`). `--pem` writes it back as PEM, which is how to turn a DER file into one. |
| `jwt-decode <token \| ->` | Decodes a JSON Web Token: its header, its payload, and the claims that matter — issuer, subject, audience, and when it was issued, becomes usable and expires, in local time and as "3 hours ago" — so a token out of an app's storage or its traffic is readable at a glance. Flags `alg=none` and an expired or not-yet-valid token. `--secret` verifies an HS256/384/512 signature, which is how to confirm a guessed or leaked signing key; nothing is sent anywhere either way. |

### Requirements

- `openssl` for `cert-info` and `jwt-decode`, and for the SHA-3 and BLAKE2b digests;
  `python3` for the CRC-32.
- The hash tools this machine has: `md5sum`/`md5`, `shasum`, `sha256sum`, `b2sum`, else
  `openssl`. `re-doctor` lists which digests `file-hash` can compute here.
- `ssdeep` or `tlsh` for the fuzzy hash, `python3` or `jq` to pretty-print a token's
  JSON (without them it's printed as it is). All optional.

## Layout and customisation

```
re_extended_shell_main  the one file your rc sources; loads every module
modules/                (README.md: how to write a module)
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
    libexec/              (binary) helper programs the commands run
local/                  YOUR files (git-ignored), see below
local.example/          templates for local/ (the installer copies them)
lib/rc.sh               shell rc handling for install and uninstall
certs/                  your proxy's root CA (git-ignored)
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

## Adding a module

A module is a folder in `modules/`, picked up automatically, with its commands, its
settings and its `re-doctor` checks. [modules/README.md](modules/README.md) is the guide
for writing one: the files a module can have, a working example you can copy, the
conventions every command follows (options, help, errors, reports), how settings are
declared, the portability rules (bash 3.2, macOS and Linux), how to test it and a
checklist.

## Notes

- Only use this on devices, apps and systems you're authorised to test.

## License

[MIT](LICENSE)

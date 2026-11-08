# RE Extended Shell

Shell tooling for Android reverse engineering and mobile app pentesting, for bash and zsh.

Its main job: one command boots an emulator (or prepares a rooted phone) with your
[ZAP](https://www.zaproxy.org/) root CA installed as a **system** CA, including on
Android 14+, and with all traffic routed through ZAP. It also has helpers for split
APKs/XAPKs, live packet capture into Wireshark, and a few other everyday tasks.

## Commands

| Command | What it does |
| --- | --- |
| `launch-emulator <AVD>` | Boots the AVD, injects the ZAP CA as a system CA and sets the global HTTP proxy to ZAP. The first boot saves a `zap-ready` snapshot, so later boots take seconds. `--clean` does a wiped boot that ignores the snapshot. |
| `launch-emulator -d [SERIAL]` | Same setup on a rooted physical device (userdebug build, or `su` via Magisk/KernelSU). Routes the proxy through `adb reverse` and opens [scrcpy](https://github.com/Genymobile/scrcpy). |
| `release-device [--reboot] [SERIAL]` | Undoes `launch-emulator -d`: clears the proxy, removes the tunnel and pushed files, closes scrcpy. Run it before unplugging the phone, or its network stops working. |
| `kill-emulator [-f] <AVD>` | Shuts an emulator down cleanly by AVD name, killing it only if it won't exit. |
| `launch-emulator-wireshark [-s SERIAL] [-i IFACE]` | Streams `tcpdump` from the device into a local Wireshark window. |
| `xapk-installer [-s SERIAL \| -n AVD] <file.xapk>` | Installs every split in an XAPK/ZIP bundle with `adb install-multiple` and pushes any OBB data. |
| `xapk-merger [options] <file.xapk\|.apks>` | Merges the splits into one installable APK with [APKEditor](https://github.com/REAndroid/APKEditor), downloaded on first use. Then zipaligns it and signs it with the debug keystore or your own (`-k`). |
| `androidcontainer` | Runs Google's Android emulator container (podman or docker) and connects adb to it as root. Linux only, it needs KVM. |

Every command takes `-h`/`--help`, and all of them have tab completion in bash and zsh,
including AVD names and device serials.

### How the CA injection works

Since Android 14, system CAs come from the Conscrypt APEX module
(`/apex/com.android.conscrypt/cacerts`), and each process sees its own mount namespace.
So remounting `/system` no longer works. [`device/inject_ca.sh`](device/inject_ca.sh)
instead copies the current CA store plus your certificate onto a tmpfs, then bind-mounts
that tmpfs over the APEX directory inside every mount namespace, including zygote's,
so apps launched afterwards trust the CA too. On older Android versions it only replaces
`/system/etc/security/cacerts`. Nothing is written to the system partition, and a reboot
reverts everything. The technique comes from
[HTTP Toolkit](https://httptoolkit.com/blog/android-14-install-system-ca-certificate/).

## Requirements

- Linux or macOS. The commands run on any bash from 3.2 up, so macOS's built-in
  `/bin/bash` is enough; your own shell can be bash or zsh
- Android SDK platform-tools and emulator, `openssl`
- ZAP listening on `127.0.0.1:9090` (change with `RE_ZAP_PORT`)
- For emulators: a **Google APIs** system image. Google Play images don't allow `adb root`.
- Optional: `scrcpy`, `wireshark`, `podman`/`docker`, Java and the SDK build-tools (for `xapk-merger`)

### macOS notes

- On Apple Silicon, create AVDs from **arm64-v8a** system images; x86_64 images don't boot there.
- `androidcontainer` is Linux-only: Google's emulator container needs `/dev/kvm`, which
  Docker Desktop and podman machine don't provide on macOS. Use `launch-emulator <AVD>` instead.
- `launch-emulator-wireshark` finds Wireshark in `/Applications` (or `~/Applications`)
  when `wireshark` isn't on your PATH.
- Bash in macOS terminals runs as a login shell and reads `~/.bash_profile`, not
  `~/.bashrc`. The installer takes care of that (see below). zsh, the default shell, needs nothing extra.

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
Running it again is safe: it updates that line in place, for example after you move
the repo. `./uninstall` removes it; `./uninstall --purge` also deletes the
downloaded APKEditor jar and the `zap-ready` snapshots of your AVDs. Neither touches
the repo itself, so delete it afterwards to remove your `local/` settings and `certs/` too.

Then export ZAP's root CA certificate to `certs/zap_root_ca.cer`, either from
*Tools → Options → Network → Server Certificates → Save*, or with
`zap.sh -cmd -certpubdump certs/zap_root_ca.cer`. PEM and DER both work. The
`<hash>.0` file Android expects is generated from it on every run.

## Layout and customisation

```
re_extended_shell_main   the one file your rc sources; loads the rest
config/                 shipped defaults, one file per kind:
  env.sh                  environment (finds ANDROID_HOME and the newest NDK)
  paths.sh                PATH (adds bin/ and the SDK tools, never duplicates)
  aliases.sh              aliases (none by default)
  completions.sh          tab completion (interactive shells only)
local/                  YOUR files, same names, loaded right after config/ (git-ignored)
local.example/          templates for local/ (the installer copies them)
bin/                    the commands, standalone bash scripts on your PATH
lib/common.sh           helpers shared by bin/
completions/            bash and zsh completion definitions
device/inject_ca.sh     runs on the device as root
certs/                  your ZAP root CA (git-ignored)
```

The modules load in this order: `env`, `paths`, `functions`, `aliases`, `completions`.
Each loads `config/<name>.sh` first, then `local/<name>.sh`. Your personal setup goes
in `local/` (extra PATH entries, your own aliases, shell functions in
`local/functions.sh`), so `git pull` never conflicts with it. Files in `config/` and
`local/` are sourced by both bash and zsh, so keep them portable or check
`$BASH_VERSION` / `$ZSH_VERSION`. The commands in `bin/` are separate bash scripts,
so they behave the same whichever shell you use.

If you change the code, keep it working on both systems: bash 3.2 (no `mapfile`,
`declare -A` or `${var,,}`) and BSD tools as well as GNU ones (no `readlink -f`,
`sed -i`, `grep -P`, `ss` or `/proc` without a fallback). `lib/common.sh` has helpers
for the OS-specific parts, e.g. `re_port_listening` and `re_proc_has_arg`.

Settings the commands read (put them in `local/env.sh`):

| Variable | Default |
| --- | --- |
| `RE_ZAP_PORT` | `9090` |
| `RE_ZAP_CERT` | `certs/zap_root_ca.cer` |
| `RE_ZAP_SNAPSHOT` | `zap-ready` |
| `RE_CONTAINER_ENGINE` | `podman`, falling back to `docker` |
| `RE_ANDROID_CONTAINER_IMAGE` | `us-docker.pkg.dev/android-emulator-268719/images/30-google-x64` |
| `APKEDITOR_JAR` | `apkeditor` on PATH, else downloaded to `~/.local/share/apkeditor/` |

## Notes

- Only use this on devices and apps you're authorised to test.
- `launch-emulator` on an AVD without a `zap-ready` snapshot does a **wiped boot**,
  which erases that AVD's user data, then saves the snapshot.
- `adb shell settings put global http_proxy` persists across reboots. On an emulator
  this is what you want. On a phone, run `release-device` when you're done.

## License

[MIT](LICENSE)

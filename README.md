# RE Extended Bash

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
| `androidcontainer` | Runs Google's Android emulator container (podman or docker) and connects adb to it as root. |

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

- Linux (macOS should mostly work but isn't tested), bash 4+ for the commands; bash or zsh as your shell
- Android SDK platform-tools and emulator, `openssl`
- ZAP listening on `127.0.0.1:9090` (change with `RE_ZAP_PORT`)
- For emulators: a **Google APIs** system image. Google Play images don't allow `adb root`.
- Optional: `scrcpy`, `wireshark`, `podman`/`docker`, Java and the SDK build-tools (for `xapk-merger`)

## Install

```sh
git clone <this repo> ~/re-extended-bash
cd ~/re-extended-bash
./install            # or: ./install --bash / ./install --zsh
```

The installer adds one line to `~/.bashrc` and/or `~/.zshrc`, under an
`# Installed by RE Extended Bash` comment, that sources `re_extended_bash_main`.
Running it again is safe: it updates that line in place, for example after you move
the repo. `./install --uninstall` removes it.

Then export ZAP's root CA certificate to `certs/zap_root_ca.cer`, either from
*Tools → Options → Network → Server Certificates → Save*, or with
`zap.sh -cmd -certpubdump certs/zap_root_ca.cer`. PEM and DER both work. The
`<hash>.0` file Android expects is generated from it on every run.

## Layout and customisation

```
re_extended_bash_main   the one file your rc sources; loads the rest
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

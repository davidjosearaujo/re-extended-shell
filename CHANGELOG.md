# Changelog

Every notable change to RE Extended Shell, newest first.

`re-extended-shell --version` prints your copy's version: its release tag, plus
the commits since it and `-dirty` when you've edited something.

## Unreleased

### Changed

- `frida-server` takes `-n AVD_NAME` like the other emulator-aware commands: either flag
  takes either an adb serial or an AVD name, and giving both is refused. Completions
  offer it in bash and zsh.

## 1.0.0 — 2026-11-13

The first release of the consolidated toolkit.

### Added

- Two crypto-triage commands in the binary module, for working out what a stripped or
  obfuscated binary does before reading its decompilation:
  - `crypto-find <file | dir>...` finds the algorithms built into a binary by the
    constants they carry, whatever the surrounding code looks like: AES by its S-box,
    the SHA and MD5 families by their round tables, Blowfish by the digits of pi,
    ChaCha by `expand 32-byte k`, SM4, CRC-32, and base64 alphabets — **including the
    shuffled custom ones apps use to hide data**. Table constants are matched in either
    byte order. It reads native binaries, dex files and the members of an APK or other
    zip (in `python3`, with its own zip reader), walks a directory, and
    `--min-confidence` filters out the weaker hits. It says plainly that RC4 and plain
    XOR have no constants to find, and that a constant is not proof the code reaches it.
  - `crypto-libs <file | dir>...` names the crypto and TLS libraries compiled or bundled
    in, from the version banners and package names in their strings: OpenSSL and its
    forks (BoringSSL, LibreSSL), mbedTLS, wolfSSL, GnuTLS, NSS, libsodium, Botan,
    Crypto++, and the Java ones in a dex (Bouncy Castle, Conscrypt, Tink, SQLCipher),
    with the version where the strings carry one. It reads the `.so`/`.dex`/`.jar`
    members of an APK with `unzip`.
- A **crypto** module, for the things you check by hand in the middle of everything
  else, with no device involved:
  - `file-hash <file>...` prints every digest this machine can compute (MD5, SHA-1,
    SHA-224, SHA-256, SHA-384, SHA-512, SHA3-256, SHA3-512, BLAKE2b, and zlib's CRC-32,
    the one zip tools show) with whichever tools are installed, all at once so a big
    file takes as long as its slowest digest, and a fuzzy hash with `ssdeep` or `tlsh`,
    which stays similar between two versions of a file. `--check SUM` compares a hash from a
    vendor page or a report with all of them and says which one matched, so you don't
    have to know what you were given; `-r` lists a tree, and `--dups` groups the files
    that share a digest; `--vt` prints the VirusTotal URL for the SHA-256, uploading
    nothing.
  - `cert-info [<file | host[:port]>]` reads a certificate (PEM, DER or a bundle) or
    connects to a host and reports its chain, the TLS version and the cipher. It prints
    the two values the Android work needs: the **SPKI pin**, the
    `<pin digest="SHA-256">` value an app's network security config carries, and the
    **`<subject_hash_old>.0`** name the certificate takes in Android's system store.
    With no argument it reads your proxy's CA; `--pem` writes it back as PEM, which is
    how to turn a DER file into one.
  - `jwt-decode <token | ->` decodes a JSON Web Token: header, payload, and the claims
    that matter, with the times in local time and as "3 hours ago". It flags `alg=none`
    and an expired or not-yet-valid token, and `--secret` verifies an HS256/384/512
    signature, which confirms a guessed or leaked signing key. Nothing is sent anywhere.
- `so-exports <file>...` in the binary module: the symbols a library or executable
  exports, demangled, with its JNI entry points (`Java_*`, `JNI_OnLoad`) first and the
  module name a Frida hook addresses it by (an ELF `SONAME`, else the file name).
  `-g` filters, `-l`/`--all` set how much is shown, `--imports` adds what it needs
  from other libraries, and it ends with an `Interceptor.attach` line ready to paste.
  Version nodes (`ZLIB_1.2.0`) are left out, since nothing can call them.
- `proto-extract <file | dir>...` recovers the `.proto` files an app was built with, so
  its protobuf traffic decodes with field names instead of numbers. It reads native and
  Go binaries, dex files, Python `_pb2` modules and APK/JAR/zip archives, in `python3`
  alone — no `protoc`.
- `bin-triage` has a "Decoded strings" section: URLs, addresses and keys hidden in
  Base64, hex, gzip or zlib data, shown with their decoding chain. Skipped above 32 MiB
  unless `--decode`; `--xor` also brute-forces single-byte XOR keys.
- `bin-triage` and `app-data` read strings with
  [`stringx`](https://codeberg.org/davidjosearaujo/stringx) when it's installed (ASCII
  and UTF-16, and its secret patterns for AWS, GitHub, Slack and Google keys, JWTs and
  private keys), falling back to binutils `strings`. `app-data` finds keys and tokens
  inside databases and binary files too.
- `apk-info [-s SERIAL] <file.apk | PKG>` — a static first look at an app, from the
  manifest, without decompiling it: the components other apps can reach and the
  permission guarding each, the URIs its deep links open, `debuggable`/`allowBackup`/
  cleartext, its network security config, the permissions it asks for and declares, its
  signature (debug certificate, Janus), its code (dex and native libraries), and the
  engine it was built with. Works on a file or on an installed package.
- `app-intent [-s SERIAL] <PKG> [COMPONENT]` — lists the app's exported components, or
  starts one as another app would (`am start`, `am startservice`, `am broadcast`,
  `content query`), with `--action`, `--data URI` and `-e KEY=VALUE`. It runs as the
  shell user even when adbd is root, so it's refused where another app would be;
  `--root` reaches the components that aren't exported.
- `app-data [-s SERIAL] [--diff DIR] <PKG>` — copies the app's private storage off a
  rooted device and lists its preferences, databases and token-like lines. `--diff`
  compares with an earlier copy, databases row by row with `sqlite3`, so you see what an
  action in the app writes.
- `re-extended-shell` shows what's installed: the modules, every command with what it
  does, the settings with their value and where it came from, the PATH entries, your
  aliases and functions, and the downloads and caches. `--modules`, `--commands`,
  `--envs`, `--paths`, `--aliases`, `--functions`, `--data` and `-m MODULE` narrow it;
  `--version` prints the version.
- A table of contents in the README, and [modules/README.md](modules/README.md), the
  guide to writing a module: the files a module can have, a worked example, the
  conventions every command follows, the portability rules, and a checklist.
- Tests for the family conventions, the outputs, `re-extended-shell` and the helpers,
  run by `./test`.
- Completion for `-s` offers every serial, not only the physical ones.
- The module layout: one folder per theme in `modules/`, each with its own commands,
  environment, PATH entries, aliases, completions and `re-doctor` checks, picked up
  automatically, and all of it behind one line in your `~/.bashrc` or `~/.zshrc`.
- `./install` and `./uninstall` manage that line (and `~/.bash_profile` on macOS), fill
  `local/` from `local.example/`, and list or delete (`--purge`) what the commands
  created outside the repo. Your settings live in the git-ignored `local/`, so `git pull`
  never touches them.
- `re-doctor` checks the shell hook and PATH, the proxy's CA and port, then each module's
  tools (including `aapt2` and `sqlite3`), emulators and devices, and says how to fix
  what's missing.
- The Android module: `launch-emulator`, `release-device`, `kill-emulator`,
  `reset-emulator`, `device-proxy`, `frida-server` (with `--ssl-unpinning`), `apk-pull`,
  `apk-decompile`, `apk-patch`, `applog`, `launch-emulator-wireshark`,
  `xapk-installer`, `xapk-merger` and `androidcontainer`, with a proxy's CA injected as
  a system CA on request, Android 14+ included.
- The binary module: `bin-triage`, a first look at ELF, Mach-O and PE files.
- macOS alongside Linux, on any bash from 3.2 up, in bash and zsh.

### Changed

- `apk-info`'s framework detection is its own `== Framework ==` section instead of one
  line, and recognises many more engines: Cocos2d-x/Cocos Creator, Unreal, Godot,
  NativeScript, Qt and Python join Flutter, React Native (with Hermes), Unity (IL2CPP
  and Mono), Xamarin/.NET, Capacitor and Cordova. It shows the evidence it matched,
  where the real code lives, and the tool to get at it (blutter, Il2CppDumper,
  hermes-dec, dnSpy, ...). It matches on three kinds of signal: the manifest's engine
  class names (`org.cocos2dx.*`, `com.unity3d.player.*`, `io.flutter.*`, ...), asset
  markers (`assets/flutter_assets/`, `global-metadata.dat`, ...) and native libraries.
  The manifest classes are the strongest: they identify an engine even when its native
  library has been renamed (a real Cocos game shipped its engine as `libgame.so`) or
  sits in a config split, and they work from the manifest alone when `unzip` isn't there.
  The detector is a shared, tested helper, `re_apk_framework`.
- `re_hash` does every digest above, not just MD5, SHA-1 and SHA-256, through whichever
  of the GNU, BSD/macOS or `openssl` tools exists (`python3` for the CRC-32), and fails
  cleanly when none of them can, so callers can skip that algorithm and say so.
- `bin-triage` and `crypto-libs` read a binary's raw strings through one shared helper
  (`re_strings_raw`): stringx when it's installed, else binutils `strings`.
- The test harness puts every module's `bin/` on `PATH`, so adding a module needs no
  change to it.
- `launch-emulator` starts the AVD as it is: no wipe, no snapshot, no root, nothing
  pushed, and its state isn't saved on exit. Everything else is a flag: `--snapshot
  [NAME]`, `--clean` (the only thing that wipes), `--read-only`, `--push-frida-server`,
  `--start-frida-server`, `--proxy PORT --ca FILE`. A running AVD is used as it is.
- The settings are proxy-neutral: `RE_PROXY_PORT` and `RE_PROXY_CERT`
  (`certs/proxy_ca.cer`) replace `RE_ZAP_PORT` and `RE_ZAP_CERT`, which are still read
  as fallbacks, along with `certs/zap_root_ca.cer`. The default snapshot is `re-ready`
  (`RE_EMULATOR_SNAPSHOT`), replacing `zap-ready` (`RE_ZAP_SNAPSHOT`).
- The CA and the proxy are set up after a snapshot is saved, so a snapshot never carries
  them; frida-server does. `re-doctor` no longer fails when there's no proxy CA or
  nothing listening on the proxy port — plenty of work doesn't need either.
- `release-device` and `device-proxy off` remove the `adb reverse` tunnel of the proxy
  that is actually set, leaving your other tunnels alone.
- Every command is one family, so once you know one you know them all. `-s/--serial`
  and `-n/--name` pick a device or an emulator everywhere, and no command takes a bare
  serial as an argument. `-o/--output` and `-f/--force` are on every command that
  writes files, and `-k/-p/-a` sign on `apk-patch`, `apk-pull --merge` and
  `xapk-merger`. (`--wiped` on `launch-emulator` is gone; use `--clean`.)
- One help layout behind `re_help`, with a Settings section showing each setting's
  current value, and one set of error helpers (`re_die`, `re_warn`,
  `re_unknown_option`, `re_unexpected_arg`, `re_usage_error`, `re_refuse_existing`), so
  errors read the same everywhere and a mistyped option always points to `--help`.
  Each module declares what it is and what it reads in a `manifest`, which `--help` and
  `re-extended-shell` both read.
- Shared report and helper functions: `re_section`, `re_row` and `re_list` for reports,
  `re_hash` in core, `re_require_root`, `re_find_apks`, and `re_manifest_records` on a
  shared awk library for `aapt2` output.
- Faster: `apk-info` and `app-intent` render components in one awk pass (600 components
  in 0.3s instead of ~8s); `app-data --diff` runs one `cksum` pass per copy instead of a
  `cmp` per file; one `pm path` per pull; one adb round trip to pick the user.

### Fixed

- A running emulator has two names, its AVD name and its `emulator-NNNN` serial, and
  every command took only one of them. Either one now works everywhere: `-s` and `-n`
  both take both, on `reset-emulator`, `kill-emulator`, `xapk-installer`,
  `launch-emulator` and the ten commands that pick a device. `reset-emulator -s
  pixel_8a` no longer says "no running emulator matches 'pixel_8a'" above a list
  containing `emulator-5554 pixel_8a`.
- `launch-emulator -s emulator-5554` took the physical-device path, reported it as a
  physical device, and refused `--snapshot`, `--clean` and `--read-only` as "for
  emulators, not physical devices" — about an emulator. An emulator serial now resolves
  to the AVD that emulator runs and stays on the emulator path. `release-device -s
  emulator-5554` no longer released an "emulator" either.
- Where the kind of target really is wrong, the error says which kind it got and what to
  run instead, rather than "not connected or not authorised" about a running AVD.
- `--read-only` lets two emulators run one AVD, so an AVD name can be ambiguous:
  the commands warn and name the one they took, and `kill-emulator` refuses a name
  outright, because the processes carry only the AVD name and killing by name took down
  an emulator nobody named (`--force` killed both).
- `bin-triage` on a 124 MB library: 11s down to 6.2s, by keeping the `readelf` output
  and the strings in temp files instead of copying them into a here-string per grep.
- `bin-triage`'s Mach-O PIE check read an empty variable and always answered no. It
  reads the header now.

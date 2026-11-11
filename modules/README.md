# Writing modules

A module is a folder in `modules/` with one theme (Android, binaries, ...): its commands,
its settings and its checks. Adding one needs no registration, because everything in
`modules/` is picked up when the shell starts. This page is for people who want to add a
module or a command. For using the toolkit, see the [main README](../README.md).

- [How modules are loaded](#how-modules-are-loaded)
- [What a module contains](#what-a-module-contains)
- [Quick start](#quick-start)
- [Writing a command](#writing-a-command)
  - [Options](#options)
  - [Help](#help)
  - [Errors and messages](#errors-and-messages)
  - [Reports](#reports)
  - [Helpers](#helpers)
- [Settings](#settings)
- [Portability](#portability)
- [Tests](#tests)
- [Checklist](#checklist)

## How modules are loaded

`re_extended_shell_main`, the one file the user's rc sources, loads one kind of file at a
time, `core` first and the other modules alphabetically, with the user's `local/` files
in between:

1. **env**: `modules/core/env.sh`, `local/env.sh`, then each module's `env.sh`
2. **paths**: each module's `paths.sh` and `bin/`, then `local/paths.sh`
3. **functions**: each module's `functions.sh`, then `local/functions.sh`
4. **aliases**: each module's `aliases.sh`, then `local/aliases.sh`
5. **completions**: each module's `completions.bash`/`.zsh`, then `local/completions.sh`

Files in `modules/` are sourced by both bash and zsh, so they must work in both (or
check `$BASH_VERSION` / `$ZSH_VERSION`). The commands in `bin/` are separate bash
scripts, so they behave the same whichever shell the user has.

A module never reads or writes the user's `local/` folder. Settings reach the commands
as exported environment variables, set by the user in `local/env.sh`.

## What a module contains

A module is the folder `modules/<name>/`. Every file in it but `manifest` is optional.
For a module called `ios`:

| File | Purpose |
| --- | --- |
| `manifest` | Required. An `about:` line saying what the module is for, and a `setting: NAME \| default \| what it does \| commands that use it` line per setting its commands read. `re-extended-shell` and every command's `--help` read it. |
| `bin/<command>` | Each command, a bash script that sources `../lib.sh`. Line 2 is a one-line summary (`# Do this to that.`), which `re-extended-shell --commands` shows. Copy the first lines of an existing command to get the self-locating `source` line. |
| `lib.sh` | Helpers and settings defaults for the module's commands. Sources `../core/lib.sh` first. Put downloads and caches under `$RE_DATA_DIR/ios/`. |
| `env.sh`, `paths.sh` | Environment and PATH for the user's interactive shell: SDK detection and `re_path_append` for its tools. Not for user settings, which are the user's to set. |
| `functions.sh`, `aliases.sh` | Shell functions (the ones that must run inside the user's shell) and aliases. |
| `completions.bash`, `completions.zsh` | Tab completion. `_re_reply_words`, `_re_reply_files` and `_re_reply_dirs` from `core/completions.bash` are available. |
| `doctor.sh` | Checks for `re-doctor`, with its `doc_section`, `doc_ok`, `doc_warn`, `doc_fail`, `doc_info` and `doc_tool` helpers. |
| `libexec/` | Helper programs the commands run that aren't commands themselves, such as a Python script (standard library only, run with `python3 -I`). |
| `device/` | Files a command pushes to a device (the Android module's CA injection script). |
| `purge.sh` | Calls `re_purge <path> [label]` for each file or folder its commands leave outside the repo (except under `$RE_DATA_DIR`, which core already covers). `./uninstall --purge` runs it. |

Look at `modules/binary/` for a small, complete example, and at `modules/core/` for the
helpers every module shares.

## Quick start

A module `demo` with one command, `demo-hello`.

**`modules/demo/manifest`**

```
# What the demo module is, and its settings.
about: A demonstration module.
setting: DEMO_GREETING | Hello | The greeting demo-hello prints | demo-hello
```

**`modules/demo/lib.sh`**

```bash
# shellcheck shell=bash
# Helpers for the demo module's commands.
. "$(dirname -- "${BASH_SOURCE[0]}")/../core/lib.sh"

DEMO_GREETING="${DEMO_GREETING:-Hello}"
```

**`modules/demo/bin/demo-hello`** (`chmod +x` it)

```bash
#!/usr/bin/env bash
# Print a greeting to a file or the screen.
# shellcheck source=../lib.sh
_re_self=$0   # follow symlinks to find the repo (no 'readlink -f' on older macOS)
while [ -L "$_re_self" ]; do
    _re_link=$(readlink -- "$_re_self")
    case "$_re_link" in /*) _re_self=$_re_link ;; *) _re_self=$(dirname -- "$_re_self")/$_re_link ;; esac
done
. "$(dirname -- "$_re_self")/../lib.sh"

usage() {
    cat <<EOF
Usage: demo-hello [-o FILE] [-f] <name>

Greets NAME with the DEMO_GREETING setting, on the screen or in a file.

Options:
  -o, --output FILE  Write to FILE instead of the screen
  -f, --force        Replace an existing output
  -h, --help         Show this help
EOF
}

OUTPUT="" FORCE="" NAME=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o|--output) re_need_arg "$1" "$#"; OUTPUT="$2"; shift 2 ;;
        -f|--force) FORCE=1; shift ;;
        -h|--help) re_help; exit 0 ;;
        -*) re_unknown_option "$1" ;;
        *)  [ -z "$NAME" ] || re_unexpected_arg "$1"
            NAME="$1"; shift ;;
    esac
done
[ -n "$NAME" ] || re_usage_error "missing <name>."

if [ -z "$OUTPUT" ]; then
    echo "$DEMO_GREETING, $NAME"
else
    re_refuse_existing "$FORCE" "$OUTPUT"
    echo "$DEMO_GREETING, $NAME" >"$OUTPUT"
    echo "Greeting saved to $OUTPUT"
fi
```

**Completion**, in `modules/demo/completions.bash` and `modules/demo/completions.zsh`:

```bash
# completions.bash
_re_complete_demo_hello() {
    local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    case "$prev" in -o|--output) _re_reply_files ""; return ;; esac
    if [[ "$cur" == -* ]]; then _re_reply_words "-o --output -f --force -h --help"; fi
}
complete -F _re_complete_demo_hello demo-hello
```

```zsh
# completions.zsh
_re_demo_hello() {
    _arguments -s \
        '(- *)'{-h,--help}'[show help]' \
        '(-o --output)'{-o,--output}'[write to this file]:file:_files' \
        '(-f --force)'{-f,--force}'[replace an existing output]' \
        '1:name:'
}
compdef _re_demo_hello demo-hello
```

Then the documentation the tests ask for (see the [checklist](#checklist)): a row for
`demo-hello` and a line for `DEMO_GREETING` in the main README, and a
`# export DEMO_GREETING=Hello` line in `local.example/env.sh`. Open a new shell and
`demo-hello --help` works, with tab completion; `re-extended-shell` lists the module,
the command and the setting.

## Writing a command

The commands are one family: they look and behave the same, so whoever knows one knows
them all. A new command must follow these conventions, and `tests/t_family.sh` checks
most of them for every command, so a mistake fails the tests.

### Options

- Every option has a long form; common ones have a short form too.
- A device is chosen with `-s, --serial SERIAL` and a running emulator by AVD name
  with `-n, --name AVD_NAME`, never by a bare argument. Either can be left out when
  only one device is connected.
- `-o, --output` sets where output goes. A command never replaces an existing output
  unless given `-f, --force`. Signing takes `-k, --keystore`, `-p, --ks-pass`,
  `-a, --alias`. A switch that turns something off is `--no-<thing>`.
- Call `re_need_arg "$1" "$#"` before reading `$2`, so a missing value is an error
  instead of an endless loop.

### Help

`usage()` prints these parts, in this order, separated by blank lines:

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

### Errors and messages

Helpers in `modules/core/lib.sh`:

- `re_die "..."` prints `Error: ...`, `re_warn "..."` prints `Warning: ...`, both on
  stderr and starting lowercase. Never `echo "Warning: ..."`.
- The option loop ends with `-*) re_unknown_option "$1" ;;` and, for arguments it
  doesn't take, `*) re_unexpected_arg "$1" ;;`.
- A command that writes a file or folder calls `re_refuse_existing "$FORCE" PATH` before
  touching it. Signing options go through `re_sign_opt` and `re_check_keystore`.
- A missing operand is `re_usage_error "missing <file.apk>."`: the error, the Usage
  line and a pointer to `--help`.
- A tool the command needs: `re_require adb` exits with a clear error when it's missing.
- Progress lines end with `...`; the last line says what was done and where the result
  is (`Merged APK: ./app_merged.apk`). No message ends with `!`.

### Reports

A command that prints a report uses `re_section "Title"`, `re_row Label value` and
`... | re_list [LIMIT]` (an indented list that ends with "... and N more"), so every
report has the same layout.

### Helpers

The helpers are documented by the comment above each one. The ones you'll reach for:

| Where | Helpers |
| --- | --- |
| `core/lib.sh` | `re_die`, `re_warn`, `re_require`, `re_need_arg`, `re_help`, `re_usage_error`, `re_unknown_option`, `re_unexpected_arg`, `re_refuse_existing`, `re_section`, `re_row`, `re_list`, `re_tilde`, `re_hash`, `re_download`, `re_version_lt`, `re_port_listening`, `re_proc_has_arg`, `re_find_gui_tool`, `re_cert_form` |
| `core/lib.sh`, strings | `re_stringx` runs `stringx` and prints its hits as `WHERE: STRING` (it fails when `stringx` isn't installed, so fall back to `strings` or `grep`); `RE_SECRET_WORDS` is the regex for words that name a secret |
| `core/lib.sh`, proxy | `RE_PROXY_PORT` and `RE_PROXY_CERT` are the user's intercepting proxy, whichever one it is: never name a specific proxy in code or messages. `re_warn_proxy_down`, `re_require_proxy_cert` |
| `android/lib.sh`, devices | `re_pick_device`, `re_adb_devices`, `re_avd_dir`, `re_running_emulators`, `re_emulator_serial`, `re_boot_completed`, `re_proxy_address`, `re_proxy_off` |
| `android/lib.sh`, root | A command that needs root gets it with `ROOT=$(re_require_root "$SERIAL") \|\| exit 1` and runs commands with `re_root_shell` |
| `android/lib.sh`, APKs | `re_pull_base_apk`, `re_find_apks`, `re_require_aapt2`, `re_apk_xmltree`; commands that read an APK's manifest use `re_manifest_records`, and awk code that reads `aapt2` output starts with `"$RE_AWK_LIB"` |
| `lib/rc.sh` (install only) | Shell rc handling for `./install` and `./uninstall` |

When a helper is useful to more than one command, put it in the module's `lib.sh` (or
in `core/lib.sh` if other modules could use it) instead of copying it.

## Settings

A setting is an environment variable the user can set in `local/env.sh`. For each one:

1. Read it in the module's `lib.sh` with a default: `NAME="${NAME:-default}"`.
2. Declare it in the module's `manifest` (`setting: NAME | default | what it does |
   commands that use it`). That one line is what `re-extended-shell --envs` and every
   command's `--help` show.
3. Add `# export NAME=value` to `local.example/env.sh`, and a row for `` `NAME` `` in the
   settings table of the module's section of the main README.

`tests/t_family.sh` checks all of this, and that every default a command reads with
`${RE_...:-...}` is declared in a manifest.

Downloads and caches go under `$RE_DATA_DIR/<module>/`, which `./uninstall --purge`
already removes. Anything a command leaves elsewhere needs a `purge.sh` line.

## Portability

The commands run on Linux and macOS, so keep them working on both: bash 3.2 (no
`mapfile`, `declare -A` or `${var,,}`) and BSD tools as well as GNU ones (no
`readlink -f`, `sed -i`, `grep -P`, `ss` or `/proc` without a fallback).
`modules/core/lib.sh` has helpers for the OS-specific parts, e.g. `re_port_listening` and
`re_proc_has_arg`. Handle optional tools by degrading, not failing: say what was skipped
and why, and add the tool to the module's `doctor.sh`. Python helpers use the standard
library only.

## Tests

```sh
./test              # everything, plus shellcheck when it is installed
./test reset        # only the test files whose name contains "reset"
```

No device, emulator or network is needed: `tests/fake/` has stand-ins for `adb`,
`emulator`, `frida`, `aapt2` and `scrcpy` that are put first on `PATH`. See
[tests/README.md](../tests/README.md) for how they work.

- `tests/t_family.sh` covers every command automatically: the help layout, unknown
  options, the one-line summary, bash and zsh completion, a README entry, `re_warn`, and
  the settings rules above. A new command only needs to follow the conventions.
- Add a `tests/t_<command>.sh` for what the command does: source `harness.sh`, set up
  the fakes it needs, `run` the command and `expect_*` on the output. If it needs more
  from `adb`, teach `tests/fake/adb` that one call.
- Run `./test` before you send a change.

## Checklist

For a new command:

- [ ] `modules/<module>/bin/<command>`, executable, summary on line 2, `usage()` in the
      family layout, the standard option loop
- [ ] Completion in `completions.bash` (`complete -F ... <command>`) and
      `completions.zsh` (`compdef ... <command>`)
- [ ] A row in the main README (the command in backticks), and its requirements in the
      module's **Requirements** list
- [ ] Its tools in the module's `doctor.sh`
- [ ] A `tests/t_<command>.sh`
- [ ] Each setting declared in the `manifest`, in `local.example/env.sh` and in the README

For a new module, also:

- [ ] `modules/<module>/manifest` with an `about:` line
- [ ] A section for it in the main README and a line under **Modules**
- [ ] `doctor.sh` and `purge.sh` where the module needs them

# Tests

```sh
./test              # everything, plus shellcheck when it is installed
./test reset        # only the test files whose name contains "reset"
./test -v           # also list every passing check
```

No device, emulator or network is needed. `tests/fake/` has stand-ins for `adb`,
`emulator`, `frida` and `scrcpy`; they are put first on `PATH` and keep their state in
a temporary directory. Every test also gets its own `HOME`, so nothing outside that
directory is read or changed.

- `harness.sh`: `fake_reset`, `fake_emulator`, `fake_device`, `run` (sets `OUT` and
  `RC`, kills a hung command after 30s) and the `expect_*` checks.
- `t_*.sh`: one file per area. A file prints `ok - ...` / `not ok - ...` lines and ends
  with `done_testing`; `./test` counts them and fails a file that stops early.
- `fake/adb` knows just enough: devices from `$FAKE_STATE/devices`, the proxy setting,
  `adb reverse` tunnels, emulator snapshots (directories under the AVD), and a
  frida-server that can be pushed, started and stopped. Every call is appended to
  `$FAKE_STATE/log`, which the tests search with `expect_log`.

`t_family.sh` checks that every command follows the family conventions (help layout,
errors, summary line, completions, README entry, manifest settings), so a new command
is covered there automatically.

To cover a new command, add a `t_<name>.sh` that sources `harness.sh`, set up the fake
devices it needs, `run` the command and `expect_*` on the result. If it needs more
from `adb`, teach `fake/adb` that one call.

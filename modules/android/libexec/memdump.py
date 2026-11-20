"""Dumps the readable memory of a running process over Frida, for app-memdump.

Usage: memdump.py [--all] DEVICE PID OUTDIR

DEVICE is an adb serial (or 'local', for testing on this machine). Writes
OUTDIR/ranges/<base address>.bin, one file per memory range (offset in the
file + base = address; pages that can't be read are zeros), and
OUTDIR/ranges.tsv: base, size, protection, backing file. Without --all, the
ranges backed by system files (libraries, the framework, fonts) are left out:
they are the same on every device and hold nothing of the app's; nor do the
JIT code caches and kernel interfaces, also left out.

Progress goes to stderr; the last stdout line is "RANGES BYTES UNREADABLE".
Needs Frida's Python bindings: run with the Python the frida CLI uses.
"""
import os
import sys

import frida

AGENT = r"""
// System files, compiled code (the JIT caches) and kernel interfaces: nothing of the app's
const SKIP = /^\/(system|system_ext|apex|vendor|product|odm)\/|^\/data\/dalvik-cache\/|\.(art|oat|odex|vdex|ttf|otf)$|^\/memfd:jit-|^\/dev\/(binderfs|__properties__|ashmem\/fontMap)|frida/i;
rpc.exports = {
  ranges(all) {
    return Process.enumerateRanges('r--')
      .filter(r => all || !(r.file && SKIP.test(r.file.path)))
      .map(r => [r.base.toString(), r.size, r.protection, r.file ? r.file.path : '']);
  },
  read(base, size) {
    try { return ptr(base).readByteArray(size); } catch (e) { return null; }
  }
};
"""

CHUNK = 1 << 20  # read this much per call
PAGE = 4096      # and page by page where a chunk fails


def main():
    args = sys.argv[1:]
    dump_all = "--all" in args
    args = [a for a in args if a != "--all"]
    if len(args) != 3:
        sys.exit(__doc__.split("\n\n")[1])
    device_id, pid, outdir = args[0], int(args[1]), args[2]

    if device_id == "local":
        device = frida.get_local_device()
    else:
        device = frida.get_device(device_id, timeout=10)
    session = device.attach(pid)
    script = session.create_script(AGENT)
    script.load()
    api = getattr(script, "exports_sync", None) or script.exports

    ranges = api.ranges(dump_all)
    total = sum(r[1] for r in ranges)
    print("Dumping %d memory ranges (%.0f MiB)..." % (len(ranges), total / 1048576.0), file=sys.stderr)

    os.makedirs(os.path.join(outdir, "ranges"), exist_ok=True)
    done = unreadable = 0
    shown = -1
    with open(os.path.join(outdir, "ranges.tsv"), "w") as index:
        index.write("base\tsize\tprotection\tfile\n")
        for base, size, prot, path in ranges:
            index.write("%s\t%d\t%s\t%s\n" % (base, size, prot, path))
            start = int(base, 16)
            with open(os.path.join(outdir, "ranges", "%s.bin" % base), "wb") as out:
                offset = 0
                while offset < size:
                    n = min(CHUNK, size - offset)
                    data = api.read(hex(start + offset), n)
                    if data is None:
                        # Part of it can't be read (a guard page, say): page by
                        # page, with zeros for what can't be, so offsets stay true
                        data = bytearray()
                        for p in range(0, n, PAGE):
                            page = api.read(hex(start + offset + p), min(PAGE, n - p))
                            if page is None:
                                page = bytes(min(PAGE, n - p))
                                unreadable += len(page)
                            data.extend(page)
                    out.write(data)
                    offset += n
                    done += n
                    percent = int(done * 10 / total) * 10 if total else 100
                    if percent != shown:
                        shown = percent
                        print("  %d%%" % percent, file=sys.stderr)
    session.detach()
    print("%d %d %d" % (len(ranges), total, unreadable))


# Frida's own errors (device not found, process gone, server not running...)
FRIDA_ERRORS = tuple(e for e in (getattr(frida, n) for n in dir(frida) if n.endswith("Error"))
                     if isinstance(e, type) and issubclass(e, Exception))

if __name__ == "__main__":
    try:
        main()
    except FRIDA_ERRORS as e:
        sys.exit("Error: Frida: %s" % e)
    except KeyboardInterrupt:
        sys.exit(130)

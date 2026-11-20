"""Fake Frida Python bindings for ./test (app-memdump's memdump.py).

The process has two memory ranges: 0x1000 (8 KiB, anonymous, its second page
unreadable) holding a password, a JWT, a bearer token and a UTF-16 string, and
0x7000 (4 KiB, backed by a system library). Every call is logged to
$FAKE_STATE/log. Pid 999 is a process that doesn't exist.
"""
import os


class ProcessNotFoundError(Exception):
    pass


def _log(msg):
    with open(os.path.join(os.environ["FAKE_STATE"], "log"), "a") as f:
        f.write("frida-py " + msg + "\n")


_PAGE1 = (b"\0\0password=hunter2\0\0"
          + b"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.c2lnbmF0dXJl\0\0"
          + b"Authorization: Bearer abcdefghijklmnop\0\0"
          + "utf16-s3cr3t-value".encode("utf-16-le") + b"\0\0")
_MEMORY = {0x1000: _PAGE1.ljust(4096, b"\0"), 0x7000: b"libc stuff".ljust(4096, b"\0")}
_UNREADABLE = {0x2000}


class _Api:
    def ranges(self, dump_all):
        _log("ranges all=%s" % dump_all)
        r = [["0x1000", 8192, "rw-", ""]]
        if dump_all:
            r.append(["0x7000", 4096, "r--", "/system/lib64/libc.so"])
        return r

    def read(self, base, size):
        start = int(base, 16)
        out = b""
        for page in range(start - start % 4096, start + size, 4096):
            if page in _UNREADABLE:
                return None
            out += _MEMORY.get(page, b"\0" * 4096)
        offset = start % 4096
        return out[offset:offset + size]


class _Script:
    exports_sync = _Api()

    def load(self):
        pass


class _Session:
    def create_script(self, source):
        return _Script()

    def detach(self):
        pass


class _Device:
    def __init__(self, ident):
        self.ident = ident

    def attach(self, pid):
        _log("attach %s %d" % (self.ident, pid))
        if pid == 999:
            raise ProcessNotFoundError("unable to find process with pid 999")
        return _Session()


def get_device(ident, timeout=0):
    return _Device(ident)


def get_local_device():
    return _Device("local")

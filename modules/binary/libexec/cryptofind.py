#!/usr/bin/env python3
"""Finds the fingerprints of crypto algorithms in a file's bytes.

Many algorithms carry constants that give them away whatever the code around
them looks like: AES its S-box, the SHA and MD5 families their round tables,
Blowfish the digits of pi, ChaCha its "expand 32-byte k" string, and so on.
This scans a file (and, for an archive, its members) for those, so you know
what crypto a stripped or obfuscated binary uses before reading a line of it.

It also spots base64 alphabets, including the shuffled custom ones apps use to
hide data: a 64-character run that is a permutation of the standard set.

Word-based constants (the SHA/MD5/CRC tables) are searched in both byte orders,
so it doesn't matter how the compiler laid them out.

Usage: cryptofind.py INPUT...
Prints one tab-separated line per algorithm found, per source:
  SOURCE  ALGORITHM  high|medium|low  0xOFFSET  DETAIL
Part of RE Extended Shell (bin/crypto-find). Standard library only.

A note on what it cannot see: RC4 and plain XOR have no constants, so their
absence here says nothing; and a constant is not proof the algorithm is
reached, only that its tables are present.
"""
import io
import os
import re
import sys
import zipfile

MAX_MEMBER = 256 << 20     # skip archive members bigger than this
MAX_DEPTH = 2              # how far to recurse into nested archives


def be(words, width):
    return b"".join(w.to_bytes(width, "big") for w in words)


def le(words, width):
    return b"".join(w.to_bytes(width, "little") for w in words)


def words_sig(name, conf, detail, words, width):
    """A constant made of 32- or 64-bit words, searched big- and little-endian."""
    return (name, conf, detail, [be(words, width), le(words, width)])


def bytes_sig(name, conf, detail, hexstr):
    return (name, conf, detail, [bytes.fromhex(hexstr)])


def ascii_sig(name, conf, detail, s):
    return (name, conf, detail, [s.encode()])


# --- The fingerprints ---------------------------------------------------------
# Each is (name, confidence, detail, [byte patterns, any of which is a hit]).

SIGNATURES = [
    bytes_sig("AES", "high", "forward S-box",
              "637c777bf26b6fc53001672bfed7ab76"
              "ca82c97dfa5947f0add4a2af9ca472c0"
              "b7fd9326363ff7cc34a5e5f171d83115"
              "04c723c31896059a071280e2eb27b275"),
    bytes_sig("AES", "high", "inverse S-box",
              "52096ad53036a538bf40a39e81f3d7fb"
              "7ce339829b2fff87348e4344c4dee9cb"),
    bytes_sig("AES", "medium", "round constants (Rcon)", "01020408102040801b36"),
    words_sig("SHA-256", "high", "round constants (K)",
              [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
               0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
               0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3], 4),
    words_sig("SHA-256", "medium", "initial hash (H)",
              [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
               0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19], 4),
    words_sig("SHA-512", "high", "round constants (K)",
              [0x428a2f98d728ae22, 0x7137449123ef65cd,
               0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
               0x3956c25bf348b538, 0x59f111f1b605d019], 8),
    words_sig("SHA-1", "medium", "round constants",
              [0x5a827999, 0x6ed9eba1, 0x8f1bbcdc, 0xca62c1d6], 4),
    words_sig("MD5", "high", "sine table (T/K)",
              [0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
               0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
               0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be], 4),
    words_sig("MD5/MD4/SHA-1", "low", "initial hash (shared by several)",
              [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476], 4),
    words_sig("Blowfish", "high", "P-array (digits of pi)",
              [0x243f6a88, 0x85a308d3, 0x13198a2e, 0x03707344,
               0xa4093822, 0x299f31d0, 0x082efa98, 0xec4e6c89,
               0x452821e6, 0x38d01377, 0xbe5466cf, 0x34e90c6c], 4),
    words_sig("CRC-32", "medium", "IEEE table",
              [0x00000000, 0x77073096, 0xee0e612c, 0x990951ba,
               0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3], 4),
    ascii_sig("ChaCha/Salsa20", "high", 'constant "expand 32-byte k"',
              "expand 32-byte k"),
    ascii_sig("ChaCha/Salsa20", "high", 'constant "expand 16-byte k"',
              "expand 16-byte k"),
    bytes_sig("SM4", "high", "S-box (Chinese national cipher)",
              "d690e9fecce13db716b614c228fb2c05"),
    words_sig("TEA/XTEA/XXTEA", "low", "delta 0x9E3779B9 (also elsewhere)",
              [0x9e3779b9], 4),
]

# The alnum characters every base64 alphabet contains; the other two vary
ALNUM = set(b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
STD_B64 = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
URL_B64 = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
RUN_RE = re.compile(rb"[A-Za-z0-9+/=_-]{64,}")


def find_base64_alphabets(buf):
    """Yields (offset, detail) for each 64-character base64 alphabet."""
    for m in RUN_RE.finditer(buf):
        run = m.group()
        for i in range(0, len(run) - 63):
            window = run[i:i + 64]
            if len(set(window)) != 64 or not ALNUM <= set(window):
                continue
            if window == STD_B64:
                yield m.start() + i, "standard alphabet"
            elif window == URL_B64:
                yield m.start() + i, "URL-safe alphabet"
            else:
                yield m.start() + i, "custom alphabet (shuffled): " + window.decode()
            break      # one per run is enough


def scan(buf, source, out, depth=0):
    """Appends (source, name, conf, offset, detail) for every hit in buf."""
    # An archive (APK, JAR, AAR, ...): scan its members, not the container's own
    # bytes, so a compressed member is still seen and a stored one isn't twice
    if depth < MAX_DEPTH and buf[:4] == b"PK\x03\x04":
        try:
            zf = zipfile.ZipFile(io.BytesIO(buf))
        except (zipfile.BadZipFile, OSError, NotImplementedError):
            zf = None
        if zf is not None:
            with zf:
                for info in zf.infolist():
                    if info.is_dir() or info.file_size > MAX_MEMBER:
                        continue
                    try:
                        data = zf.read(info)
                    except (zipfile.BadZipFile, OSError, NotImplementedError, RuntimeError, EOFError):
                        continue
                    scan(data, source + "!" + info.filename, out, depth + 1)
            return

    for name, conf, detail, patterns in SIGNATURES:
        for pat in patterns:
            off = buf.find(pat)
            if off != -1:
                out.append((source, name, conf, off, detail))
                break
    for off, detail in find_base64_alphabets(buf):
        out.append((source, "Base64", "high", off, detail))


def main():
    out = []
    for path in sys.argv[1:]:
        if os.path.isdir(path):
            for root, _, files in os.walk(path):
                for f in sorted(files):
                    p = os.path.join(root, f)
                    try:
                        with open(p, "rb") as fh:
                            scan(fh.read(), p, out)
                    except OSError:
                        pass
        else:
            try:
                with open(path, "rb") as fh:
                    scan(fh.read(), path, out)
            except OSError as e:
                sys.stderr.write("cannot read %s: %s\n" % (path, e))

    # One line per (source, algorithm), the strongest confidence kept, in a
    # stable order: by source as given, then confidence, then name
    rank = {"high": 0, "medium": 1, "low": 2}
    best = {}
    order = []
    for source, name, conf, off, detail in out:
        key = (source, name, detail)
        if key not in best:
            order.append(key)
            best[key] = (conf, off)
        elif rank[conf] < rank[best[key][0]]:
            best[key] = (conf, off)
    srcorder = {}
    for source, _, _ in order:
        srcorder.setdefault(source, len(srcorder))
    for key in sorted(order, key=lambda k: (srcorder[k[0]], rank[best[k][0]], k[1])):
        source, name, detail = key
        conf, off = best[key]
        print("%s\t%s\t%s\t0x%x\t%s" % (source, name, conf, off, detail))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Report mixin targets that no longer exist in the client this mod patches.

Every injector here is optional, because one redirect is shared across several targets and
legitimately matches nothing in some of them. That also means a target LiquidBounce renamed
stops being patched without any complaint, and the crash it was covering comes back. This
reads the targets out of the mixin sources and checks each one still resolves.
"""
import argparse
import re
import struct
import sys
import zipfile

MIXIN_TARGETS = re.compile(
    r'@Mixin\(\s*(?:value\s*=\s*)?(?:targets\s*=\s*)?\{?([^)]*?)\}?\s*(?:,\s*remap[^)]*)?\)', re.S
)
QUOTED = re.compile(r'"([^"]+)"')
AT_FIELD = re.compile(r'target\s*=\s*"L([^;]+);([^:]+):([^"]+)"')
AT_METHOD = re.compile(r'target\s*=\s*"L([^;]+);([^(]+)(\([^"]*)"')


def classes_in(jar):
    """{internal name: {(member, descriptor)}} for a jar and its nested jars."""
    found = {}
    with zipfile.ZipFile(jar) as z:
        for name in z.namelist():
            if name.endswith(".class"):
                found.setdefault(name[:-6], set())
            elif name.endswith(".jar"):
                import io
                found.update(classes_in(io.BytesIO(z.read(name))))
    return found


def members_of(jar, internal):
    """(name, descriptor) declared by a class, searched across nested jars."""
    with zipfile.ZipFile(jar) as z:
        for name in z.namelist():
            if name == internal + ".class":
                return _members(z.read(name))
            if name.endswith(".jar"):
                import io
                got = members_of(io.BytesIO(z.read(name)), internal)
                if got is not None:
                    return got
    return None


def _members(data):
    count = struct.unpack(">H", data[8:10])[0]
    pool, i, off = {}, 1, 10
    while i < count:
        tag = data[off]
        if tag == 1:
            n = struct.unpack(">H", data[off + 1:off + 3])[0]
            pool[i] = data[off + 3:off + 3 + n].decode("utf-8", "replace"); off += 3 + n
        elif tag in (7, 8, 16, 19, 20):
            off += 3
        elif tag == 15:
            off += 4
        elif tag in (3, 4, 9, 10, 11, 12, 17, 18):
            off += 5
        elif tag in (5, 6):
            off += 9; i += 1
        else:
            return set()
        i += 1
    p = off + 6
    p += 2 + struct.unpack(">H", data[p:p + 2])[0] * 2
    out = set()
    for _ in range(2):
        cnt = struct.unpack(">H", data[p:p + 2])[0]; p += 2
        for _ in range(cnt):
            _a, ni, di = struct.unpack(">HHH", data[p:p + 6]); p += 6
            out.add((pool.get(ni), pool.get(di)))
            attrs = struct.unpack(">H", data[p:p + 2])[0]; p += 2
            for _ in range(attrs):
                p += 6 + struct.unpack(">I", data[p + 2:p + 6])[0]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--client", required=True, help="the LiquidBounce jar")
    ap.add_argument("sources", nargs="+", help="the mixin sources")
    args = ap.parse_args()

    present = classes_in(args.client)
    problems = []
    for path in args.sources:
        with open(path) as fh:
            text = fh.read()
        targets = []
        for block in MIXIN_TARGETS.findall(text):
            targets += [t for t in QUOTED.findall(block) if "." in t]
        for t in targets:
            if t.replace(".", "/") not in present:
                problems.append(f"{path}: @Mixin target is gone: {t}")
        # @At targets naming a class outside okhttp, i.e. one the client owns
        for owner, _name, _desc in AT_FIELD.findall(text):
            if owner.startswith(("okhttp3/", "okio/")):
                continue
            if owner not in present:
                problems.append(f"{path}: @At owner is gone: {owner}")
        print(f"{path}: {len(targets)} target(s)")
        for t in targets:
            mark = "ok " if t.replace(".", "/") in present else "GONE"
            print(f"   {mark} {t}")

    if problems:
        print("\n" + "\n".join(problems))
        return 1
    print("\nEvery mixin target resolves against the client.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

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
AT_FIELD = re.compile(r'target\s*=\s*"L([^;]+);([^:"]+):([^"]+)"')
AT_METHOD = re.compile(r'target\s*=\s*"L([^;]+);([^("]+)(\([^"]*)"')
# A NEW target names only the type it builds, where the client's bytecode names a constructor.
AT_NEW = re.compile(r'target\s*=\s*"(\([^")]*\))L([^;"]+);"')


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


def joined(text):
    """Java concatenates adjacent string literals, so a target split over lines is one string."""
    return re.sub(r'"\s*\+\s*"', "", text)


def redirected(text):
    """Members a mixin source redirects, keyed the way the covered file writes them."""
    out = set()
    for owner, name, desc in AT_FIELD.findall(text):
        out.add(f"{owner}.{name}{desc}")
    for owner, name, desc in AT_METHOD.findall(text):
        out.add(f"{owner}.{name}{desc}")
    for args, owner in AT_NEW.findall(text):
        out.add(f"{owner}.<init>{args}V")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--client", required=True, help="the LiquidBounce jar")
    ap.add_argument("--covered", help="the covered members file, whose users must be targeted")
    ap.add_argument("--config", action="append", default=[],
                    help="a mixin config, in which every source must be registered; repeatable")
    ap.add_argument("sources", nargs="+", help="the mixin sources")
    args = ap.parse_args()

    present = classes_in(args.client)
    problems = []
    all_targets = set()
    by_source = {}
    for path in args.sources:
        with open(path) as fh:
            text = joined(fh.read())
        targets = []
        for block in MIXIN_TARGETS.findall(text):
            targets += [t for t in QUOTED.findall(block) if "." in t]
        if not targets:
            problems.append(f"{path}: no @Mixin target was parsed, so nothing was checked")
        for t in targets:
            all_targets.add(t.replace(".", "/"))
            if t.replace(".", "/") not in present:
                problems.append(f"{path}: @Mixin target is gone: {t}")
        # An @At owner the client itself declares has to still be there
        for owner, _name, _desc in AT_FIELD.findall(text) + AT_METHOD.findall(text):
            if owner.startswith(("okhttp3/", "okio/")):
                continue
            if owner not in present:
                problems.append(f"{path}: @At owner is gone: {owner}")
        by_source[path] = (set(t.replace(".", "/") for t in targets), redirected(text))
        print(f"{path}: {len(targets)} target(s), {len(by_source[path][1])} redirected member(s)")
        for t in targets:
            mark = "ok " if t.replace(".", "/") in present else "GONE"
            print(f"   {mark} {t}")

    # A mixin left out of its config is compiled and shipped but never applied, and nothing
    # about the run says so.
    registered = set()
    for cfg in args.config:
        import json
        with open(cfg) as fh:
            data = json.load(fh)
        pkg = data.get("package", "")
        for entry in data.get("mixins", []) + data.get("client", []) + data.get("server", []):
            registered.add(f"{pkg}.{entry}" if pkg else entry)
    if args.config:
        for path in args.sources:
            name = path.split("src/main/java/")[-1][:-5].replace("/", ".")
            if name not in registered:
                problems.append(f"{path}: {name} is in no mixin config, so it never applies")

    # The covered file records which classes reference each member the mod handles. A class
    # listed there but not targeted by any mixin is one nothing redirects, so the member is
    # only covered on paper.
    if args.covered:
        with open(args.covered) as fh:
            for line in fh:
                line = line.split("#")[0].strip()
                if not line or " <- " not in line:
                    continue
                member, _, users = line.partition(" <- ")
                member = member.strip()
                for user in (u.strip() for u in users.split(",")):
                    if not user:
                        continue
                    # Targeting the class is not enough: the mixin that targets it has to be
                    # the one redirecting this member, or nothing rewrites the read.
                    if not any(user in tgts and member in mems
                               for tgts, mems in by_source.values()):
                        problems.append(
                            f"covered-members.txt: {member} is claimed for {user}, but no mixin "
                            f"both targets that class and redirects that member"
                        )

    if problems:
        print("\n" + "\n".join(problems))
        return 1
    print("\nEvery mixin target resolves against the client.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

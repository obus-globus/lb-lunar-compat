#!/usr/bin/env python3
"""Report okhttp/okio members LiquidBounce binds that a host's older okhttp does not declare.

Reads every class LiquidBounce ships, including its nested jar-in-jar libraries, collects the
okhttp and okio members they reference, and resolves each against the okhttp a host bundles.
A member missing there is what throws NoSuchFieldError or NoSuchMethodError at runtime.
"""
import argparse
import struct
import sys
import zipfile
from collections import defaultdict

PKGS = ("okhttp3/", "okio/")


def _pool(data):
    """(constant pool, offset past it) for a class file."""
    if data[:4] != b"\xca\xfe\xba\xbe":
        raise ValueError("not a class file")
    count = struct.unpack(">H", data[8:10])[0]
    pool, i, off = {}, 1, 10
    while i < count:
        tag = data[off]
        if tag == 1:
            n = struct.unpack(">H", data[off + 1:off + 3])[0]
            pool[i] = ("utf", data[off + 3:off + 3 + n].decode("utf-8", "replace"))
            off += 3 + n
        elif tag in (7, 8, 16, 19, 20):
            pool[i] = (tag, struct.unpack(">H", data[off + 1:off + 3])[0]); off += 3
        elif tag == 15:
            pool[i] = (tag, None); off += 4
        elif tag in (3, 4, 9, 10, 11, 12, 17, 18):
            pool[i] = (tag, struct.unpack(">HH", data[off + 1:off + 5])); off += 5
        elif tag in (5, 6):
            pool[i] = (tag, None); off += 9; i += 1
        else:
            raise ValueError(f"constant pool tag {tag}")
        i += 1
    return pool, off


def references(data):
    """okhttp/okio members this class references, as (owner, name, descriptor)."""
    pool, _ = _pool(data)
    def utf(i):
        return pool[i][1] if pool.get(i, (None,))[0] == "utf" else None

    out = set()
    for tag, val in pool.values():
        if tag in (9, 10, 11) and isinstance(val, tuple):
            owner_entry, nt_entry = pool.get(val[0]), pool.get(val[1])
            if not owner_entry or owner_entry[0] != 7 or not nt_entry or nt_entry[0] != 12:
                continue
            owner = utf(owner_entry[1])
            if owner and owner.startswith(PKGS):
                out.add((owner, utf(nt_entry[1][0]), utf(nt_entry[1][1])))
    return out


def declared(data):
    """(name, descriptor) of every field and method a class declares, plus its supertypes."""
    pool, off = _pool(data)
    def utf(i):
        return pool[i][1] if pool.get(i, (None,))[0] == "utf" else None

    def cls(i):
        return utf(pool[i][1]) if pool.get(i, (None,))[0] == 7 else None

    p = off + 2
    this_name = cls(struct.unpack(">H", data[p:p + 2])[0]); p += 2
    supers = []
    sup = struct.unpack(">H", data[p:p + 2])[0]; p += 2
    if sup:
        supers.append(cls(sup))
    n = struct.unpack(">H", data[p:p + 2])[0]; p += 2
    for _ in range(n):
        supers.append(cls(struct.unpack(">H", data[p:p + 2])[0])); p += 2
    members = set()
    for _ in range(2):
        cnt = struct.unpack(">H", data[p:p + 2])[0]; p += 2
        for _ in range(cnt):
            _acc, ni, di = struct.unpack(">HHH", data[p:p + 6]); p += 6
            members.add((utf(ni), utf(di)))
            attrs = struct.unpack(">H", data[p:p + 2])[0]; p += 2
            for _ in range(attrs):
                length = struct.unpack(">I", data[p + 2:p + 6])[0]; p += 6 + length
    return this_name, members, [s for s in supers if s]


def load(jar, prefixes=None):
    """{internal name: (members, supertypes)} for classes in a jar, recursing into nested jars."""
    out = {}
    with zipfile.ZipFile(jar) as z:
        for name in z.namelist():
            if name.endswith(".class"):
                try:
                    cn, members, supers = declared(z.read(name))
                except Exception:
                    continue
                if cn and (prefixes is None or cn.startswith(prefixes)):
                    out[cn] = (members, supers)
            elif name.endswith(".jar"):
                try:
                    import io
                    out.update(load(io.BytesIO(z.read(name)), prefixes))
                except Exception:
                    pass
    return out


def collect(jar):
    """{(owner, name, desc): [classes that reference it]} across a jar and its nested jars."""
    refs = defaultdict(list)
    with zipfile.ZipFile(jar) as z:
        for name in z.namelist():
            if name.endswith(".class"):
                # A class in one of these packages is the client's own copy. Where the host has
                # the same class its copy wins and the client's never loads, so its references
                # say nothing; only the ones the host lacks are collected, by the caller.
                if name.startswith(PKGS):
                    continue
                try:
                    for ref in references(z.read(name)):
                        refs[ref].append(name[:-6])
                except Exception:
                    continue
            elif name.endswith(".jar"):
                try:
                    import io
                    for ref, users in collect(io.BytesIO(z.read(name))).items():
                        refs[ref].extend(users)
                except Exception:
                    pass
    return refs


def resolves(owner, member, host, shipped):
    """Whether owner declares member, walking supertypes."""
    seen, queue = set(), [owner]
    while queue:
        cur = queue.pop()
        if cur in seen:
            continue
        seen.add(cur)
        if cur in shipped:
            return True
        entry = host.get(cur)
        if entry is None:
            continue
        members, supers = entry
        if member in members:
            return True
        queue.extend(supers)
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--client", required=True, help="the LiquidBounce jar")
    ap.add_argument("--host", required=True, help="a jar holding the host's okhttp and okio")
    ap.add_argument("--covered", help="a file listing members this mod already handles")
    args = ap.parse_args()

    host = load(args.host, PKGS)
    if not host:
        print(f"no okhttp or okio classes in {args.host}", file=sys.stderr)
        return 2
    covered = {}
    if args.covered:
        with open(args.covered) as fh:
            for line in fh:
                line = line.split("#")[0].strip()
                if not line:
                    continue
                member, _, users = line.partition(" <- ")
                covered[member.strip()] = {u.strip() for u in users.split(",") if u.strip()}
    refs = collect(args.client)
    provided = set(load(args.client, PKGS))

    # Classes the client ships that the host does not have do load at runtime, and what they
    # call is as able to be missing as anything else. Collect their references separately: the
    # mod redirects the client's own call sites, not these, so they are reported not failed.
    # Start from the ones the client's own code enters through, then follow what those reach
    # among the same set. A class further down the chain runs just as surely as the first, so
    # stopping at one hop would leave the rest of the path unexamined.
    only = provided - set(host)
    bodies = {}
    with zipfile.ZipFile(args.client) as z:
        for name in z.namelist():
            if not name.endswith(".jar"):
                continue
            import io
            with zipfile.ZipFile(io.BytesIO(z.read(name))) as iz:
                for entry in iz.namelist():
                    if entry.endswith(".class") and entry[:-6] in only:
                        bodies[entry[:-6]] = references(iz.read(entry))

    reached = {owner for owner, _n, _d in refs} & only
    queue = list(reached)
    while queue:
        for owner, _n, _d in bodies.get(queue.pop(), ()):
            if owner in only and owner not in reached:
                reached.add(owner)
                queue.append(owner)

    orphan_refs = {}
    for internal in sorted(reached):
        for ref in bodies.get(internal, ()):
            if ref[0] in host and not resolves(ref[0], ref[1:], host, set()):
                orphan_refs.setdefault(ref, []).append(internal)

    missing = []
    for (owner, name, desc), users in sorted(refs.items()):
        if owner in provided and owner not in host:
            continue  # the client ships this class itself
        if resolves(owner, (name, desc), host, set()):
            continue
        key = f"{owner}.{name}{desc}"
        if key in covered:
            # Handled, but only for the classes the mixin actually targets. A new referencing
            # class reaches the same member through a redirect that does not apply to it.
            stray = sorted(set(users) - covered[key])
            if not stray:
                continue
            missing.append((owner, name, desc, stray))
            continue
        missing.append((owner, name, desc, sorted(set(users))))

    print(f"host okhttp/okio classes: {len(host)}")
    print(f"members referenced: {len(refs)}")
    print(f"handled by this mod: {len(covered)} member(s)")
    if orphan_refs:
        print(f"\nnote: {len(orphan_refs)} reference(s) from classes only the client ships, which"
              f" load when the host lacks them and are not redirected:")
        for (owner, name, desc), users in sorted(orphan_refs.items()):
            print(f"  {owner}.{name}{desc}")
            for u in sorted(set(users))[:2]:
                print(f"      {u}")
    if not missing:
        print("\nEvery member the client's own classes reference resolves against the host.")
        return 0
    print(f"\n{len(missing)} member(s) do not resolve:\n")
    for owner, name, desc, users in missing:
        print(f"  {owner}.{name}{desc}")
        for u in users:
            print(f"      {u}")
    return 1


if __name__ == "__main__":
    sys.exit(main())

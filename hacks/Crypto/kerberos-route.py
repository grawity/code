#!/usr/bin/env python
import os
import sys

realms = set()
trusts = {}
paths = {}

inf = float("inf")

def trace(*a):
    if os.environ.get("DEBUG"):
        print("#", *a)

def add_trust(src, dst, bidirectional=False):
    if src in trusts:
        if type(trusts[src]) != set:
            trusts[src] = set(trusts[src])
        trusts[src].add(dst)
    else:
        trusts[src] = {dst}

def count_tabs(s):
    n = 0
    while n < len(s) and s[n] == "\t":
        n += 1
    return n

def parse_trusts(fh):
    depth = 0
    path = [None]
    for line in fh:
        indent = count_tabs(line)
        realm = line.strip()
        flags = set()
        if not realm or realm.startswith("#"):
            continue

        if realm.startswith(">"):
            flags.add("out")
            realm = realm[1:]

        realms.add(realm)

        if indent > depth:
            if (indent - depth > 1) or (path[0] is None):
                print("parse error: excessive indent")
                return
            depth += 1
            path.append(realm)
            trace(depth, "  "*depth, "--> %r @ %r" % (realm, path))
        elif indent < depth:
            while indent < depth:
                path.pop()
                depth -= 1
            path[-1] = realm
            trace(depth, "  "*depth, "<-- %r @ %r" % (realm, path))
        else:
            path[-1] = realm
            trace(depth, "  "*depth, "... %r @ %r" % (realm, path))

        if depth > 0:
            a = path[-2]
            b = path[-1]
            yield (a, b)
            if "out" not in flags:
                yield (b, a)

def load_trusts(fh):
    for a, b in parse_trusts(fh):
        add_trust(a, b)

def dump_trusts():
    print("= Trusts =")
    print()
    for src in sorted(trusts):
        print("%s -> %s" % (src, trusts[src]))
    print()

def find_path(src, dst, seen=None):
    if src not in trusts:
        return []

    if src == dst:
        return [src]

    if dst in trusts[src]:
        return [src, dst]

    best_dist = inf
    best_path = []
    seen = seen or {src}
    for via in trusts[src]:
        if via in seen:
            continue
        path = find_path(via, dst, seen | {via})
        dist = len(path) or inf
        if dist < best_dist:
            best_dist = dist
            best_path = [src] + path
    return best_path

def create_paths():
    realms = list(trusts)
    realms.sort()
    for src in realms:
        for dst in realms:
            paths[src, dst] = find_path(src, dst)

def dump_paths():
    print("= Paths =")
    print()
    for pair in sorted(paths):
        src, dst = pair
        if paths[pair]:
            #print("%r -> %r" % (pair, paths[pair]))
            print("%r" % (pair,))
            print("\t%r" % (paths[pair],))
    print()

"""

a, b, c, d
    a {
        d = b
        d = c
    }

a, b, c
    a {
        c = b
    }

a, b
    a {
        b = .
    }

"""

def dump_capaths():
    print("[capaths]")
    print()
    realms = list(trusts)
    realms.sort()
    for src in sorted(realms):
        print("\t%s = {" % src)
        for dst in realms:
            if src == dst:
                continue
            path = paths[src, dst]
            #print("\t\t\033[38;5;239m# %s via {%s}\033[m" % (dst, ", ".join(path)))
            if len(path) < 2:
                # 0 hops means "no path"
                # 1 hop means the only hop is ourselves, which is filtered out above
                #print("\t\t# no path to %s" % dst)
                continue
            # 2 or more hops means src is the first hop, dst is last
            # discard both, and ensure there's still at least one subtag
            path = path[1:-1] or ["."]
            for hop in path:
                print("\t\t%s = %s" % (dst, hop))
        print("\t}")
    print()

if __name__ == "__main__":
    try:
        cmd = sys.argv.pop(1)
    except IndexError:
        cmd = "capaths"

    load_trusts(sys.stdin)

    create_paths()

    if cmd == "all":
        dump_trusts()
        dump_paths()
        dump_capaths()
    elif cmd == "trusts":
        dump_trusts()
    elif cmd == "paths":
        dump_paths()
    elif cmd == "capaths":
        dump_capaths()
    elif cmd == "route":
        src, dst = sys.argv[1:]
        p = find_path(src, dst)
        if p:
            print(" → ".join(p))
        else:
            print("No path found.")

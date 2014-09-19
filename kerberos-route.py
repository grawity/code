#!/usr/bin/env python

trusts = {
    'NULLROUTE.EU.ORG': {
        'CLUENET.ORG',
        'NATHAN7.EU',
        'KYRIASIS.COM',
    },
    'XSEDE.ORG': set(),
    'NTAS.IN': {
        'NULLROUTE.EU.ORG',
        'KRA.NTAS.IN',
    },
}

paths = {}

inf = float("inf")

def add_reverse_trusts():
    realms = list(trusts)
    for src in realms:
        for dst in trusts[src]:
            if dst in trusts:
                trusts[dst].add(src)
            else:
                trusts[dst] = {src}

def dump_trusts():
    print("= Trusts =")
    print()
    for src in sorted(trusts):
        print("\t%s -> %s" % (src, trusts[src]))
    print()

def find_path(src, dst, seen=None):
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
            #print("\t%r -> %r" % (pair, paths[pair]))
            print("\t%r" % (pair,))
            print("\t\t%r" % (paths[pair],))
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
    print("= [capaths] =")
    print()
    realms = list(trusts)
    realms.sort()
    for src in realms:
        print("\t%s = {" % src)
        for dst in realms:
            if src == dst:
                continue
            path = paths[src, dst]
            #print("\t\t\033[38;5;239m# %s via {%s}\033[m" % (dst, ", ".join(path)))
            if len(path) < 2:
                # 0 hops means "no path"
                # 1 hop means the only hop is ourselves, which is filtered out above
                print("\t\t# no path to %s" % dst)
                continue
            # 2 or more hops means src is the first hop, dst is last
            # discard both, and ensure there's still at least one subtag
            path = path[1:-1] or ["."]
            for hop in path:
                print("\t\t%s = %s" % (dst, hop))
        print("\t}")
    print()

if __name__ == "__main__":
    add_reverse_trusts()
    dump_trusts()
    create_paths()
    dump_paths()
    dump_capaths()

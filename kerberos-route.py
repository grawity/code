#!/usr/bin/env python

trusts = {
    'NULLROUTE.EU.ORG': {
        'CLUENET.ORG',
        'NATHAN7.EU',
        'KYRIASIS.COM',
    },
    'XSEDE.ORG': {},
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
        return 0, [src]

    if dst in trusts[src]:
        return 1, [src, dst]
    
    best_dist = inf
    best_path = []
    seen = seen or {src}
    for via in trusts[src]:
        if via in seen:
            continue
        dist, path = find_path(via, dst, seen | {via})
        dist += 1
        if dist < best_dist:
            best_dist = dist
            best_path = [src] + path
    return best_dist, best_path

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
            dist, path = paths[src, dst]
            if not path:
                print("\t\t# no path to %s" % dst)
                continue
            if len(path) > 2:
                path = path[1:-1]
            else:
                path = ["."]
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

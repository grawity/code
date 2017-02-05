#!/usr/bin/env python
import ipaddress
import subprocess

def chunk(vec, size):
    for i in range(0, len(vec), size):
        yield vec[i:i+size]

def resolve(name):
    return subprocess.check_output(["name2addr", "-6", name]).decode().strip()

def list_addresses():
    with subprocess.Popen(["ip", "-6", "addr", "show", "scope", "global"],
                          stdout=subprocess.PIPE) as proc:
        for line in proc.stdout:
            line = line.rstrip().decode()
            if line[0].isdecimal():
                idx, iface, rest = line.split(": ", 2)
            else:
                line = line.split()
                if line[0] == "inet6":
                    addr = ipaddress.IPv6Interface(line[1])
                    yield (iface, addr)

def list_subnets():
    seen = set()
    for iface, addr in list_addresses():
        r = (iface, addr.network)
        if r not in seen:
            yield r
            seen.add(r)

def list_gateways():
    with subprocess.Popen(["ip", "-6", "route", "show", "exact", "::/0"],
                          stdout=subprocess.PIPE) as proc:
        for line in proc.stdout:
            line = line.rstrip().decode().split()
            if line[0] in {"unreachable"}:
                kind = line.pop(0)
            if line[0] == "default":
                line[0] = "::/0"
            net = ipaddress.IPv6Network(line.pop(0))
            kvs = {}
            for k, v in chunk(line, 2):
                if k in {"from", "via", "dev"}:
                    kvs[k] = v
            if "from" not in kvs:
                yield (kvs["dev"], kvs["via"])

ula_root = ipaddress.IPv6Network("fc00::/7")

gateways = dict(list_gateways())

gateways["zt1"] = resolve("sky.zt1.nullroute.eu.org")

for iface, net in list_subnets():
    print("found prefix", net, "on", iface)
    #if ula_root.overlaps(net):
    if not net.is_global:
        print("- prefix is not global; skipping")
        continue
    gw = gateways.get(iface)
    if not gw:
        print("- no gateway for this interface; skipping")
        continue
    print("+", iface, "from", net, "via", gw)
    subprocess.run(["sudo", "ip", "-6", "route", "replace",
                    "::/0", "from", str(net), "via", gw, "dev", iface])

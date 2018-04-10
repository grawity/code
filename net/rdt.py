#!/usr/bin/env python3
import argparse
import dns.resolver
import socket
import struct
import sys

def is_inet4addr(addr):
    try:
        return socket.inet_pton(socket.AF_INET, addr)
    except:
        return None

def is_inet6addr(addr):
    try:
        return socket.inet_pton(socket.AF_INET6, addr)
    except:
        return None

def is_inetaddr(addr):
    return is_inet4addr(addr) or is_inet6addr(addr)

def color(addr):
    if addr == "(none)":
        fmt = "38;5;9"
    elif is_inet4addr(addr):
        fmt = "38;5;13"
    elif is_inet6addr(addr):
        fmt = "38;5;14"
    else:
        fmt = "38;5;214"
    return "\033[%sm%s\033[m" % (fmt, addr)

def to_ptr(addr):
    packed = is_inetaddr(addr)
    if len(packed) == 4:
        ip = [str(i) for i in struct.unpack("4B", packed)]
        fmt = "%s.in-addr.arpa."
    elif len(packed) == 16:
        ip = packed.hex()
        fmt = "%s.ip6.arpa."
    return fmt % ".".join(reversed(ip))

def query(addr, rrtype):
    try:
        answer = dns.resolver.query(addr, rrtype)
        return [rr.to_text() for rr in answer]
    except:
        return []

def resolve(addr):
    if is_inetaddr(addr):
        rr = query(to_ptr(addr), "PTR")
    else:
        rr = query(addr, "CNAME")
        if not rr:
            rr4 = query(addr, "A")
            rr6 = query(addr, "AAAA")
            rr = [*rr4, *rr6]
    return rr

def rdt(addr, depth=0, skip=None, visited=None):
    if not skip:
        skip = set()
    if not visited:
        visited = set()

    print("   " * depth + color(addr) + " = ", end="", flush=True)

    addresses = resolve(addr)
    addresses.sort() # XXX

    if addresses:
        print(", ".join(addresses))
        for nextaddr in addresses:
            if nextaddr in visited or nextaddr in skip:
                continue
            visited.add(nextaddr)
            rdt(nextaddr, depth+1, skip|{*addresses}, visited)
    else:
        print(color("(none)"))

ap = argparse.ArgumentParser()
ap.add_argument("addr", nargs="+")
args = ap.parse_args()

for i, arg in enumerate(args.addr):
    if i > 0:
        print()
    rdt(arg)

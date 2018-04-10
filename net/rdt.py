#!/usr/bin/env python3
import argparse
import ipaddress
import dns.resolver
import sys
from nullroute.core import Core
from pprint import pprint

def is_inet4addr(addr):
    try:
        return ipaddress.IPv4Address(addr)
    except ValueError:
        return None

def is_inet6addr(addr):
    try:
        return ipaddress.IPv6Address(addr)
    except ValueError:
        return None

def is_inetaddr(addr):
    try:
        return ipaddress.ip_address(addr)
    except ValueError:
        return None

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
    return ipaddress.ip_address(addr).reverse_pointer

def query(addr, rrtype):
    Core.debug("looking up %r / %s", addr, rrtype)
    try:
        answer = dns.resolver.query(addr, rrtype)
        return [rr.to_text() for rr in answer]
    except dns.resolver.NoAnswer as e:
        Core.debug("got NoAnswer: %s", e)
        return []
    except dns.resolver.NXDOMAIN as e:
        Core.debug("got NXDOMAIN: %s", e)
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

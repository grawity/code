#!/usr/bin/env python
import os
import sys
from pprint import pprint
import socket

states = []
parse = False

conn_tokens = {"src", "dst", "sport", "dport"}
int_tokens = {"sport", "dport", "use"}

def try_resolve_addr(addr):
    if os.environ.get("noresolve"):
        return addr
    try:
        r = socket.gethostbyaddr(addr)
        #print("got %r" % (r,))
        return r[0] or addr
    except socket.herror:
        return addr
    except Exception as e:
        print(repr(e))
        return addr

def fmt_addr(addr, port, resolve=False):
    #if port == 53:
    #    resolve = False
    if resolve:
        addr = try_resolve_addr(addr)
    if ":" in addr:
        return "[%s]:%s" % (addr, port)
    else:
        return "%s:%s" % (addr, port)

def fmt_addr_foo(stuff, addr_key, port_key, resolve=False):
    if port_key in stuff:
        return fmt_addr(stuff[addr_key], stuff[port_key], resolve)
    else:
        return stuff[addr_key]

for line in sys.stdin:
    line = line.strip()
    if line == "~ # cat /proc/self/net/nf_conntrack":
        parse = True
    elif line.startswith("~ #"):
        break
    elif parse:
        family_s, family_i, proto_s, proto_i, timeout, *data_v = line.split()
        family_i = int(family_i)
        proto_i = int(proto_i)
        timeout = int(timeout)
        data_h = {"outgoing": {}, "incoming": {}, "flags": set()}
        if proto_s == "tcp":
            data_h["tcp_state"] = data_v.pop(0)
        for token in data_v:
            if "=" in token:
                key, val = token.split("=", 1)
                if key in int_tokens:
                    val = int(val)
                if key in conn_tokens:
                    if key in data_h["incoming"]:
                        data_h["outgoing"][key] = val
                    else:
                        data_h["incoming"][key] = val
                else:
                    data_h[key] = val
            elif token.startswith("[") and token.endswith("]"):
                data_h["flags"].add(token[1:-1])
        try:
            incoming_src = fmt_addr_foo(data_h["incoming"], "src", "sport")
            incoming_dst = fmt_addr_foo(data_h["incoming"], "dst", "dport", True)
            outgoing_src = fmt_addr_foo(data_h["outgoing"], "src", "sport")
            outgoing_dst = fmt_addr_foo(data_h["outgoing"], "dst", "dport")
            print("[%s] %s -> %s" %
                  (proto_s, incoming_src, incoming_dst))
        except KeyError:
            pprint(data_h)
            raise

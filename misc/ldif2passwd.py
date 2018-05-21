#!/usr/bin/env python3
import base64
from collections import defaultdict
import sys

def ldif_unwrapper(input):
    buf = None
    for line in input:
        line = line.rstrip("\n")
        if line.startswith(" "):
            buf += line[1:]
            continue
        if buf is not None:
            yield buf
        buf = line
    if buf is not None:
        yield buf

def ldif_parser(input):
    entry = defaultdict(set)
    for line in input:
        if not line:
            if entry.get("dn"):
                yield entry
            entry = defaultdict(set)
            continue
        if line.startswith("#"):
            continue
        try:
            key, val = line.split(": ", 1)
        except ValueError:
            key, val = line, ""
        if key.endswith(":"):
            key = key[:-1]
            val = base64.b64decode(val)
            val = val.decode(errors="surrogateescape")
        entry[key.lower()].add(val)
    if entry.get("dn"):
        yield entry

def account_parser(input):
    for entry in input:
        if "posixAccount" not in entry["objectclass"]:
            continue
        entry = {k: [*v] for k, v in entry.items()}
        yield [
            entry["uid"][0],
            "x",
            entry["uidnumber"][0],
            entry["gidnumber"][0],
            entry.get("gecos", entry.get("cn", [""]))[0],
            entry.get("homedirectory", ["/"])[0],
            entry.get("loginshell", [""])[0],
        ]

def passwd_builder(input):
    for entry in input:
        entry = [x.replace(":", "_") for x in entry]
        yield ":".join(entry)

fn = sys.stdin
fn = ldif_unwrapper(fn)
fn = ldif_parser(fn)
fn = account_parser(fn)
fn = passwd_builder(fn)

for line in fn:
    print(line)

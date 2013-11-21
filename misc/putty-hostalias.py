#!/usr/bin/env python2
# encoding=utf-8
# hostalias v1.0 - adds host alias support to PuTTY
# (c) 2010 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
from __future__ import print_function
import os, sys, subprocess
from os.path import expanduser, expandvars

#alias_file = expanduser("~/.hostaliases")
alias_file = expandvars("${AppData}/hostaliases.txt")

"""
Usage:
    hostalias [puttyargs] [user@]host[:port]

    Both <user> or <port>, when specified, override those from hostaliases.

hostalias syntax:

    entry: <aliases> = [<user>@][<hostmask>][:<port>] [puttyargs]

    Aliases are comma-separated. Spaces are ignored. Hosts are lowercase'd.

    If <hostmask> starts with a period ".", then it is _appended_ to input.

    All asterisks "*" in <hostmask> are replaced with input.

    <hostmask> is not required if user and/or port are specified. (If you only
    want to set puttyargs but keep user@host:port, set host to *)

    Aliases can be chained but not looped.

Example hostalias entries:

    # host 'box' becomes 'homebox.dyndns.org'
    box = homebox.dyndns.org

    # hosts 'foo' and 'bar' get '.example.com' appended
    # user is set to 'joeuser' unless overriden by commandline
    foo, bar = joeuser@.example.com

    # host 'mail' becomes 'adm-mail.example.com'
    # host 'log' becomes 'adm-log.example.com'
    # port is set to 21032 unless overriden by commandline
    mail, log = adm-*.example.com:21032
"""

def split_address(address):
    user, host, port = None, address, None
    if "@" in host:
        user, host = host.split("@", 2)
    if ":" in host:
        host, port = host.split(":", 2)
    try:
        port = int(port)
    except TypeError:
        port = None

    return user, host, port

class addr():
    def gethost(self, input):
        if self.host == "" or self.host is None:
            return ""
        elif self.host[0] == ".":
            return input + self.host
        elif "*" in target.host:
            return self.host.replace("*", input)
        else:
            return self.host

    def __init__(s):
        s.user, s.host, s.port, s.opts = None, None, None, []

def read_aliases(file):
    alias_map = {}
    for line in open(file, "r"):
        line = line.strip()
        if line == "" or line[0] == "#": continue

        names, data = line.split("=", 1)

        names = names.lower().replace(" ", "").split(",")
        data = data.split()

        target = addr()

        target.user, target.host, target.port = split_address(data[0])
        target.opts = data[1:]

        for n in names:
            if n not in alias_map: alias_map[n] = addr()
            if target.user: alias_map[n].user = target.user
            if target.host: alias_map[n].host = target.host
            if target.port: alias_map[n].port = target.port
            alias_map[n].opts.extend(target.opts)
    return alias_map

if len(sys.argv) >= 2:
    host = sys.argv.pop()
    extargs = sys.argv[1:]
else:
    print("Usage: %s [puttyargs] [user@]host[:port]"
        % os.path.basename(sys.argv[0]),
        file=sys.stderr)
    sys.exit(2)

user, host, port = split_address(host)

aliases = read_aliases(alias_file)

def dump():
    defuser = user or ""
    defport = port or 22
    for k in aliases:
        target = aliases[k]
        print("%s = %s@%s:%s %s" % (k, target.user or defuser, target.host or k, target.port or defport, subprocess.list2cmdline(target.opts)))

#dump()
#sys.exit()

# resolve alias
antiloop = []
while host not in antiloop:
    host = host.lower()
    antiloop.append(host)
    if host in aliases:
        target = aliases[host]

        if target.host == "":
            pass
        elif target.host.startswith("."):
            host += target.host
        elif "*" in target.host:
            host = target.host.replace("*", host)
        else:
            host = target.host

        if user == None:
            user = target.user
        if port == None:
            port = target.port

        extargs += target.opts

if host in antiloop[:-1]:
    antiloop.append(t_host)
    print("Loop detected:", " -> ".join(antiloop))

pArgs = ["putty", host]
pArgs += extargs
if user:
    pArgs += ["-l", user]
if port:
    pArgs += ["-P", str(port)]

print("exec:", subprocess.list2cmdline(pArgs))
subprocess.Popen(pArgs)

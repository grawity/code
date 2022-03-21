#!/usr/bin/env python3
import argparse
import socket
import sys

def finger(user, host, whois=False, *, timeout=10):
    wflag = "/W " if whois else ""
    query = "%s%s\r\n" % (wflag, user)
    query = query.encode("utf-8")
    gai = socket.getaddrinfo(host, "finger",
                             type=socket.SOCK_STREAM,
                             flags=socket.AI_CANONNAME)
    cname = None
    for (family, type, proto, canonname, sockaddr) in gai:
        addr = sockaddr[0]
        cname = canonname or cname
        try:
            sock = socket.socket(family, type, proto)
            sock.settimeout(timeout)
            sock.connect(sockaddr)
            sock.send(query)
            data = b""
            while True:
                buf = sock.recv(4096)
                if buf:
                    data += buf
                else:
                    break
            sock.close()
            data = data.replace(b"\r\n", b"\n")
            if not data.strip():
                print("Empty response from %s" % addr, file=sys.stderr)
                continue
            return cname or addr, data
        except OSError as e:
            print("Connect to %s failed: %s" % (addr, e), file=sys.stderr)
    print("Unable to query \"%s@%s\"" % (user, host), file=sys.stderr)
    exit(1)

parser = argparse.ArgumentParser()
parser.add_argument("-l", "--long", action="store_true",
                    help="request 'long' or 'whois' result (/W query)")
parser.add_argument("target", metavar="[user]@host",
                    nargs="?", default="",
                    help="remote system to query")
args = parser.parse_args()

if args.target:
    if "@" in args.target:
        user, host = args.target.rsplit("@", 1)
    else:
        user, host = args.target, "localhost"
else:
    user, host = "", "localhost"

addr, data = finger(user, host, args.long)

print("[%s]" % addr)
data = data.decode("utf-8", errors="replace")
data = data.replace("\033", "\\e")
print(data, end="")

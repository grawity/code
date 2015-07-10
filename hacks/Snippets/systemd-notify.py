import os
import socket

def notify(*args):
    if "NOTIFY_SOCKET" in os.environ:
        addr = os.environ["NOTIFY_SOCKET"]
        if addr.startswith("@"):
            addr = "\0" + addr[1:]
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        data = "\n".join(args).encode("utf-8")
        sock.sendto(data, addr)

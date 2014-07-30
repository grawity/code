import os, socket

def notify(*args):
    path = os.environ.get("NOTIFY_SOCKET", None)

    if not path:
        return
    elif path[0] == "@":
        path = "\0" + path[1:]

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)

    msg = "\n".join(args).encode("utf-8")
    sock.sendto(msg, path)

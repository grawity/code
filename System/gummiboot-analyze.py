#!/usr/bin/env python
import struct

UUID_GUMMIBOOT = "4a67b082-0a4c-41cf-b6c7-440b29bb8c4f"

def read_var(name, uuid):
    path = "/sys/firmware/efi/efivars/%s-%s" % (name, uuid)
    with open(path, "rb") as fh:
        flags = fh.read(4)
        data = fh.read()
    return flags, data

def read_str(name, uuid):
    _, data = read_var(name, uuid)
    text = data.decode("utf-16le").rstrip("\0")
    return text

def ifmt(nsec):
    x = nsec / 1000
    # TODO: MAKE THIS FORMAT MINUTES, HOURS, ETC
    return "%.3fs" % (x / 1000)

loader_init = int(read_str("LoaderTimeInitUSec", UUID_GUMMIBOOT))
loader_exec = int(read_str("LoaderTimeExecUSec", UUID_GUMMIBOOT))

print("Startup finished in",
        ifmt(loader_init), "(firmware)",
        "+", ifmt(loader_exec-loader_init), "(loader)",
        "+ ??? (userspace)")

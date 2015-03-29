#!/usr/bin/env python2
from __future__ import print_function
import os
import sys

def fromhex(string):
    return string.replace(":", "").replace("-", "").decode("hex")

def tohex(string, sep=""):
    if sep:
        return sep.join(byte.encode("hex") for byte in string)
    else:
        return string.encode("hex")

def bluez_import_system(local_addr=None, root="/"):
    path = os.path.join(root, "var/lib/bluetooth")
    keys = {}
    for subdir in os.listdir(path):
        local_addr = fromhex(subdir)
        keyfile = os.path.join(path, subdir, "linkkeys")
        with open(keyfile, "r") as fd:
            keys.update(bluez_import_fd(fd, local_addr))
    return keys

def bluez_import_fd(fd, local_addr):
    keys = {}
    for line in (fd or sys.stdin):
        addr, key, _ = line.split(" ", 2)
        addr = fromhex(addr)
        key = fromhex(key)
        keys[addr] = key
    return {local_addr: keys}

def bluez_export_system(keys, root="/"):
    path = os.path.join(root, "/var/lib/bluetooth")
    os.umask(077)
    for local_addr, dev_keys in keys.items():
        device_path = os.path.join(path, tohex(local_addr, ":").upper())
        if not os.path.exists(device_path):
            os.mkdir(device_path)
        keyfile = os.path.join(device_path, "linkkeys")
        with open(keyfile, "w") as fd:
            bluez_export_fd(fd, {local_addr: dev_keys})

def bluez_export_fd(fd, keys):
    for local_addr, dev_keys in keys.items():
        for addr, key in dev_keys.items():
            addr = tohex(addr, ":").upper()
            key = tohex(key).upper()
            fd.write("%s %s %d %d\n" % (addr, key, 0, 4))

def winreg_export_fd(fd, keys):
    fd.write("Windows Registry Editor Version 5.00\r\n")
    for local_addr, dev_keys in keys.items():
        fd.write("\r\n")
        fd.write("[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\" \
            "Services\\BTHPORT\\Parameters\\Keys\\%s]\r\n" % tohex(local_addr))
        for addr, key in dev_keys.items():
            fd.write("\"%s\"=hex:%s\r\n" % (tohex(addr), tohex(key, ",")))

arg0 = os.path.basename(sys.argv[0])
try:
    in_format, out_format, local_addr = sys.argv[1:]
except ValueError:
    print("Usage: %s <input-format> <output-format> <local-address>" % arg0,
          file=sys.stderr)
    sys.exit(2)

formats = {}
formats["bluez"] = {
    "import": (bluez_import_system, bluez_import_fd),
    "export": (bluez_export_system, bluez_export_fd),
}
formats["winreg"] = {
    "import": (None, None),
    "export": (None, winreg_export_fd),
}

in_root = "/snow"
in_fmt, in_system, in_file      = 'bluez', True, None
out_fmt, out_system, out_file   = 'winreg', False, "-"

import_system, import_fd = formats[in_fmt]["import"]
export_system, export_fd = formats[out_fmt]["export"]

if in_system:
    keys = import_system(root=in_root)
elif in_file == "-":
    keys = import_fd(sys.stdin)
else:
    keys = import_fd(open(in_file, "r"))

if out_system:
    export_system(keys)
elif out_file == "-":
    export_fd(sys.stdout, keys)
else:
    export_fd(open(out_file, "w"), keys)

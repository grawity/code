#!/usr/bin/env python3
# vim: ts=4:sw=4:et
# SPDX-License-Identifier: GPL-2.0 OR GPL-3.0
#
# lsusb-010.py
#
# Displays your USB devices in reasonable form.
#
# Copyright (c) 2009 Kurt Garloff <garloff@suse.de>
# Copyright (c) 2013 Kurt Garloff <kurt@garloff.de>
#
# Usage: See usage()

import getopt
import os
import re
import sys

prefix = "/sys/bus/usb/devices/"

usbvendors = {}
usbproducts = {}
usbclasses = {}

norm = "\033[0;0m"
bold = "\033[0;1m"
red =  "\033[0;31m"
green= "\033[0;32m"
amber= "\033[0;33m"
blue = "\033[0;34m"

HUB_ICLASS = 0x09

def readattr(path, name):
    "Read attribute from sysfs and return as string"
    f = open(prefix + path + "/" + name);
    return f.readline().rstrip("\n");

def readlink(path, name):
    "Read symlink and return basename"
    return os.path.basename(os.readlink(prefix + path + "/" + name));

class Options:
    show_interfaces = False
    show_hub_interfaces = False
    show_endpoints = False
    no_hubs = False
    no_empty_hubs = False
    colors = ("", "", "", "", "", "")
    usbids_file = "/usr/share/hwdata/usb.ids"

def ishexdigit(str):
    "return True if all digits are valid hex digits"
    return bool({*str} <= {*"0123456789abcdef"})

def parse_usb_ids(path):
    "Parse /usr/share/usb.ids and fill usbvendors, usbproducts, usbclasses"
    id = 0
    sid = 0
    mode = 0
    strg = ""
    cstrg = ""
    for ln in open(path, "r", errors="replace").readlines():
        if ln[0] == '#':
            continue
        ln = ln.rstrip('\n')
        if len(ln) == 0:
            continue
        if ishexdigit(ln[0:4]):
            mode = 0
            id = int(ln[:4], 16)
            name = ln[6:]
            usbvendors[id] = name
            continue
        if ln[0] == '\t' and ishexdigit(ln[1:3]):
            sid = int(ln[1:5], 16)
            # USB devices
            if mode == 0:
                name = ln[7:]
                usbproducts[id, sid] = name
                continue
            elif mode == 1:
                name = ln[5:]
                if name != "Unused":
                    strg = cstrg + ":" + name
                else:
                    strg = cstrg + ":"
                usbclasses[id, sid, -1] = strg
                continue
        if ln[0] == 'C':
            mode = 1
            id = int(ln[2:4], 16)
            cstrg = ln[6:]
            usbclasses[id, -1, -1] = cstrg
            continue
        if mode == 1 and ln[0] == '\t' and ln[1] == '\t' and ishexdigit(ln[2:4]):
            prid = int(ln[2:4], 16)
            name = ln[6:]
            usbclasses[id, sid, prid] = strg + ":" + name
            continue
        mode = 2
    usbclasses[0xFF, 0xFF, 0xFF] = "Vendor Specific"

def find_usb_prod(vid, pid):
    "Return device name from USB Vendor:Product list"
    name = ""
    vendor = usbvendors.get(vid)
    if vendor:
        name = str(vendor)
        product = usbproducts.get((vid, pid))
        if product:
            name += " " + str(product)
    return name

def find_usb_class(cid, sid, pid):
    "Return USB protocol from usbclasses list"
    uclass = usbclasses.get((cid, sid, pid)) \
          or usbclasses.get((cid, sid, -1)) \
          or usbclasses.get((cid, -1, -1))
    if uclass:
        return str(uclass)
    return ""

devlst = [
    'host',                 # usb-storage
    'video4linux/video',    # uvcvideo et al.
    'sound/card',           # snd-usb-audio
    'net/',                 # cdc_ether, ...
    'input/input',          # usbhid
    'usb:hiddev',           # usb hid
    'bluetooth/hci',        # btusb
    'ttyUSB',               # btusb
    'tty/',                 # cdc_acm
    'usb:lp',               # usblp
    #'usb/lp',              # usblp
    'usb/',                 # hiddev, usblp
]

def find_storage(hostno):
    "Return SCSI block dev names for host"
    res = ""
    for ent in os.listdir("/sys/class/scsi_device"):
        (host, bus, tgt, lun) = ent.split(":")
        if host == hostno:
            try:
                for ent2 in os.listdir("/sys/class/scsi_device/%s/device/block" % ent):
                    res += ent2 + " "
            except:
                pass
    return res

def find_dev(driver, usbname):
    "Return pseudo devname that's driven by driver"
    res = ""
    for nm in devlst:
        dir = prefix + usbname
        prep = ""
        idx = nm.find('/')
        if idx != -1:
            prep = nm[:idx+1]
            dir += "/" + nm[:idx]
            nm = nm[idx+1:]
        ln = len(nm)
        try:
            for ent in os.listdir(dir):
                if ent[:ln] == nm:
                    res += prep+ent+" "
                    if nm == "host":
                        res += "(" + find_storage(ent[ln:])[:-1] + ")"
        except:
            pass
    return res

class UsbEndpoint:
    "Container for USB endpoint info"
    def __init__(self, parent, fname, level):
        self.parent = parent
        self.level = level
        self.fname = fname
        self.path = ""
        self.epaddr = 0
        self.len = 0
        self.ival = ""
        self.type = ""
        self.attr = 0
        self.max = 0
        if self.fname:
            self.read(self.fname)

    def read(self, fname):
        self.fname = fname
        self.path = self.parent.path + "/" + fname
        self.epaddr = int(readattr(self.path, "bEndpointAddress"), 16)
        ival = int(readattr(self.path, "bInterval"), 16)
        if ival:
            self.ival = "(%s)" % readattr(self.path, "interval")
        self.len = int(readattr(self.path, "bLength"), 16)
        self.type = readattr(self.path, "type")
        self.attr = int(readattr(self.path, "bmAttributes"), 16)
        self.max = int(readattr(self.path, "wMaxPacketSize"), 16)

    def __str__(self):
        indent = self.level + len(self.parent.fname)
        return "%-17s  %s(EP) %02x: %s %s attr %02x len %02x max %03x%s\n" % \
            (" " * indent, Options.colors[5], self.epaddr, self.type,
             self.ival, self.attr, self.len, self.max, Options.colors[0])


class UsbInterface:
    "Container for USB interface info"
    def __init__(self, parent, fname, level=1):
        self.parent = parent
        self.level = level
        self.path = ""
        self.fname = fname
        self.iclass = 0
        self.isclass = 0
        self.iproto = 0
        self.noep = 0
        self.driver = ""
        self.devname = ""
        self.protoname = ""
        self.eps = []
        if self.fname:
            self.read(self.fname)

    def read(self, fname):
        self.fname = fname
        self.path = self.parent.path + "/" + fname
        self.iclass = int(readattr(self.path, "bInterfaceClass"), 16)
        self.isclass = int(readattr(self.path, "bInterfaceSubClass"), 16)
        self.iproto = int(readattr(self.path, "bInterfaceProtocol"), 16)
        self.noep = int(readattr(self.path, "bNumEndpoints"))
        try:
            self.driver = readlink(self.path, "driver")
            self.devname = find_dev(self.driver, fname)
        except:
            pass
        self.protoname = find_usb_class(self.iclass, self.isclass, self.iproto)
        if Options.show_endpoints:
            for dirent in os.listdir(prefix + self.path):
                if dirent.startswith("ep_"):
                    ep = UsbEndpoint(self, dirent, self.level+1)
                    self.eps.append(ep)

    def __str__(self):
        plural = (" " if self.noep == 1 else "s")
        strg = "%-17s (IF) %02x:%02x:%02x %iEP%s (%s) %s%s %s%s%s\n" % \
            (" " * self.level+self.fname, self.iclass,
             self.isclass, self.iproto, self.noep,
             plural, self.protoname,
             Options.colors[3], self.driver,
             Options.colors[4], self.devname, Options.colors[0])
        if Options.show_endpoints and self.eps:
            for ep in self.eps:
                strg += str(ep)
        return strg

class UsbDevice:
    "Container for USB device info"
    def __init__(self, parent, fname, level=0):
        self.parent = parent
        self.level = level
        self.fname = fname
        self.iclass = 0
        self.isclass = 0
        self.iproto = 0
        self.vid = 0
        self.pid = 0
        self.name = ""
        self.usbver = ""
        self.speed = ""
        self.maxpower = ""
        self.noports = 0
        self.nointerfaces = 0
        self.driver = ""
        self.devname = ""
        self.interfaces = []
        self.children = []
        if self.fname:
            self.read(self.fname)
            self.readchildren()

    def read(self, fname):
        self.fname = fname
        self.path = fname
        self.iclass = int(readattr(self.path, "bDeviceClass"), 16)
        self.isclass = int(readattr(self.path, "bDeviceSubClass"), 16)
        self.iproto = int(readattr(self.path, "bDeviceProtocol"), 16)
        self.vid = int(readattr(self.path, "idVendor"), 16)
        self.pid = int(readattr(self.path, "idProduct"), 16)

        try:
            self.name = readattr(self.path, "manufacturer") + " " + readattr(self.path, "product")
        except:
            pass
        else:
            m = re.match(r"Linux [^ ]* (.hci[-_]hcd) .HCI Host Controller", self.name)
            if m:
                self.name = m.group(1)

        if not self.name:
            self.name = find_usb_prod(self.vid, self.pid)

        # Some USB Card readers have a better name then Generic ...
        if self.name.startswith("Generic"):
            self.name = find_usb_prod(self.vid, self.pid) or self.name

        try:
            ser = readattr(fname, "serial")
            # Some USB devs report literal 'serial' as the serial number. Suppress that.
            if ser and ser != "serial":
                self.name += " " + ser
        except:
            pass

        self.usbver = readattr(self.path, "version")
        self.speed = readattr(self.path, "speed")
        self.maxpower = readattr(self.path, "bMaxPower")
        self.noports = int(readattr(self.path, "maxchild"))

        try:
            self.nointerfaces = int(readattr(self.path, "bNumInterfaces"))
        except:
            pass

        try:
            self.driver = readlink(self.path, "driver")
            self.devname = find_dev(self.driver, fname)
        except:
            pass

    def readchildren(self):
        for dirent in os.listdir(prefix + self.fname):
            if not dirent[0].isdigit():
                continue

            if os.path.exists(prefix + dirent + "/bInterfaceClass"):
                iface = UsbInterface(self, dirent, self.level+1)
                self.interfaces.append(iface)
            else:
                usbdev = UsbDevice(self, dirent, self.level+1)
                self.children.append(usbdev)

        usbsortkey = lambda obj: [int(x) for x in re.split(r"[-:.]", obj.fname)]
        self.interfaces.sort(key=usbsortkey)
        self.children.sort(key=usbsortkey)

    def __str__(self):
        is_hub = (self.iclass == HUB_ICLASS)
        if is_hub:
            if Options.no_hubs:
                buf = ""
            if Options.no_empty_hubs and len(self.children) == 0:
                return ""
            col = Options.colors[2]
        else:
            col = Options.colors[1]

        if not (is_hub and Options.no_hubs):
            plural = (" " if self.nointerfaces == 1 else "s")
            buf = "%-16s %s%04x:%04x%s %02x %s%5sMBit/s %s %iIF%s (%s%s%s)" % \
                (" " * self.level + self.fname,
                 Options.colors[1], self.vid, self.pid, Options.colors[0],
                 self.iclass, self.usbver, self.speed, self.maxpower,
                 self.nointerfaces, plural, col, self.name, Options.colors[0])

            if is_hub and not Options.show_hub_interfaces:
                buf += " %shub%s\n" % (Options.colors[2], Options.colors[0])
            else:
                buf += "\n"
                if Options.show_endpoints:
                    ep = UsbEndpoint(self, "ep_00", self.level+1)
                    buf += str(ep)
                if Options.show_interfaces:
                    for iface in self.interfaces:
                        buf += str(iface)

        for child in self.children:
            buf += str(child)

        return buf

def usage():
    "Displays usage information"
    print("Usage: lsusb.py [options]")
    print()
    print("Options:")
    #     "|-------|-------|-------|-------|-------"
    print("  -h, --help            display this help")
    print("  -i, --interfaces      display interface information")
    print("  -I, --hub-interfaces  display interface information, even for hubs")
    print("  -u, --hide-empty-hubs suppress empty hubs")
    print("  -U, --hide-hubs       suppress all hubs")
    print("  -c, --color           use colors")
    print("  -C, --no-color        disable colors")
    print("  -e, --endpoints       display endpoint info")
    print("  -f FILE, --usbids-path FILE")
    print("                        override filename for /usr/share/usb.ids")
    print()
    print("Use lsusb.py -ciu to get a nice overview of your USB devices.")

def read_usb():
    "Read toplevel USB entries and print"
    for dirent in os.listdir(prefix):
        if dirent.startswith("usb"):
            usbdev = UsbDevice(None, dirent, 0)
            print(usbdev, end="")

def main(argv):
    short_options = "hiIuUwcCef:"
    long_options = [
        "help",
        "interfaces",
        "hub-interfaces",
        "hide-empty-hubs",
        "hide-hubs",
        "color",
        "no-color",
        "usbids-path=",
        "endpoints",
    ]

    try:
        (optlist, args) = getopt.gnu_getopt(argv[1:], short_options, long_options)
    except getopt.GetoptError as e:
        print("Error:", e, file=sys.stderr)
        sys.exit(2)

    use_colors = None

    for opt in optlist:
        if opt[0] in {"-h", "--help"}:
            usage()
            sys.exit(0)
        elif opt[0] in {"-i", "--interfaces"}:
            Options.show_interfaces = True
        elif opt[0] in {"-I", "--hub-interfaces"}:
            Options.show_interfaces = True
            Options.show_hub_interfaces = True
        elif opt[0] in {"-u", "--hide-empty-hubs"}:
            Options.no_empty_hubs = True
        elif opt[0] in {"-U", "--hide-hubs"}:
            Options.no_empty_hubs = True
            Options.no_hubs = True
        elif opt[0] in {"-c", "--color"}:
            use_colors = True
        elif opt[0] in {"-C", "--no-color"}:
            use_colors = False
        elif opt[0] == "-w":
            print("warning: option", opt[0], "is no longer supported", file=sys.stderr)
        elif opt[0] in {"-f", "--usbids-path"}:
            Options.usbids_file = opt[1]
        elif opt[0] in {"-e", "--endpoints"}:
            Options.show_endpoints = True

    if args:
        print("Error: excess args %s ..." % args[0], file=sys.stderr)
        sys.exit(2)

    if use_colors is None:
        use_colors = (os.environ.get("TERM", "dumb") != "dumb") and sys.stdout.isatty()
    if use_colors:
        Options.colors = (norm, bold, red, green, amber, blue)

    parse_usb_ids(Options.usbids_file)
    read_usb()

if __name__ == "__main__":
    main(sys.argv)

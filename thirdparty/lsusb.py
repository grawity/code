#!/usr/bin/env python3
# vim: ts=8:sw=8:noet
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

# Global options
showint = False
showhubint = False
noemptyhub = False
nohub = False
showeps = False

prefix = "/sys/bus/usb/devices/"
usbids = "/usr/share/hwdata/usb.ids"

usbvendors = {}
usbproducts = {}
usbclasses = {}

esc = chr(27)
norm = esc + "[0;0m"
bold = esc + "[0;1m"
red =  esc + "[0;31m"
green= esc + "[0;32m"
amber= esc + "[0;33m"
blue = esc + "[0;34m"

HUB_ICLASS = 0x09

cols = ("", "", "", "", "", "")

def readattr(path, name):
	"Read attribute from sysfs and return as string"
	f = open(prefix + path + "/" + name);
	return f.readline().rstrip("\n");

def readlink(path, name):
	"Read symlink and return basename"
	return os.path.basename(os.readlink(prefix + path + "/" + name));

class UsbClass:
	"Container for USB Class/Subclass/Protocol"
	def __init__(self, cl, sc, pr, str = ""):
		self.pclass = cl
		self.subclass = sc
		self.proto = pr
		self.desc = str

	def __str__(self):
		return self.desc

class UsbVendor:
	"Container for USB Vendors"
	def __init__(self, vid, vname = ""):
		self.vid = vid
		self.vname = vname

	def __str__(self):
		return self.vname

class UsbProduct:
	"Container for USB VID:PID devices"
	def __init__(self, vid, pid, pname = ""):
		self.vid = vid
		self.pid = pid
		self.pname = pname

	def __str__(self):
		return self.pname

def ishexdigit(str):
	"return True if all digits are valid hex digits"
	return bool({*str} <= {*"0123456789abcdef"})

def parse_usb_ids():
	"Parse /usr/share/usb.ids and fill usbvendors, usbproducts, usbclasses"
	id = 0
	sid = 0
	mode = 0
	strg = ""
	cstrg = ""
	for ln in open(usbids, "r", errors="replace").readlines():
		if ln[0] == '#':
			continue
		ln = ln.rstrip('\n')
		if len(ln) == 0:
			continue
		if ishexdigit(ln[0:4]):
			mode = 0
			id = int(ln[:4], 16)
			name = ln[6:]
			usbvendors[id] = UsbVendor(id, name)
			continue
		if ln[0] == '\t' and ishexdigit(ln[1:3]):
			sid = int(ln[1:5], 16)
			# USB devices
			if mode == 0:
				name = ln[7:]
				usbproducts[id, sid] = UsbProduct(id, sid, name)
				continue
			elif mode == 1:
				name = ln[5:]
				if name != "Unused":
					strg = cstrg + ":" + name
				else:
					strg = cstrg + ":"
				usbclasses[id, sid, -1] = UsbClass(id, sid, -1, strg)
				continue
		if ln[0] == 'C':
			mode = 1
			id = int(ln[2:4], 16)
			cstrg = ln[6:]
			usbclasses[id, -1, -1] = UsbClass(id, -1, -1, cstrg)
			continue
		if mode == 1 and ln[0] == '\t' and ln[1] == '\t' and ishexdigit(ln[2:4]):
			prid = int(ln[2:4], 16)
			name = ln[6:]
			usbclasses[id, sid, prid] = UsbClass(id, sid, prid, strg + ":" + name)
			continue
		mode = 2

def find_usb_prod(vid, pid):
	"Return device name from USB Vendor:Product list"
	strg = ""

	dev = UsbVendor(vid, "")
	vendor = usbvendors.get(vid)
	if vendor:
		strg = str(vendor)
	else:
		return ""

	dev = UsbProduct(vid, pid, "")
	product = usbproducts.get((vid, pid))
	if product:
		strg += " " + str(product)
	else:
		return ""

	return strg

def find_usb_class(cid, sid, pid):
	"Return USB protocol from usbclasses list"
	if cid == 0xff and sid == 0xff and pid == 0xff:
		return "Vendor Specific"

	uclass = usbclasses.get((cid, sid, pid)) \
		or usbclasses.get((cid, sid, -1)) \
		or usbclasses.get((cid, -1, -1))
	if uclass:
		return str(uclass)
	else:
		return ""


devlst = [
	'host',			# usb-storage
	'video4linux/video', 	# uvcvideo et al.
	'sound/card',		# snd-usb-audio
	'net/',			# cdc_ether, ...
	'input/input',		# usbhid
	'usb:hiddev',		# usb hid
	'bluetooth/hci',	# btusb
	'ttyUSB',		# btusb
	'tty/',			# cdc_acm
	'usb:lp',		# usblp
	#'usb/lp',		# usblp
	'usb/',			# hiddev, usblp
]

def find_storage(hostno):
	"Return SCSI block dev names for host"
	res = ""
	for ent in os.listdir("/sys/class/scsi_device/"):
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
	def __init__(self, parent = None, indent = 18):
		self.parent = parent
		self.indent = indent
		self.fname = ""
		self.epaddr = 0
		self.len = 0
		self.ival = ""
		self.type = ""
		self.attr = 0
		self.max = 0

	def read(self, fname):
		fullpath = ""
		if self.parent:
			fullpath = self.parent.fullpath + "/"
		fullpath += fname
		self.epaddr = int(readattr(fullpath, "bEndpointAddress"), 16)
		ival = int(readattr(fullpath, "bInterval"), 16)
		if ival:
			self.ival = "(%s)" % readattr(fullpath, "interval")
		self.len = int(readattr(fullpath, "bLength"), 16)
		self.type = readattr(fullpath, "type")
		self.attr = int(readattr(fullpath, "bmAttributes"), 16)
		self.max = int(readattr(fullpath, "wMaxPacketSize"), 16)

	def __str__(self):
		return "%-17s  %s(EP) %02x: %s %s attr %02x len %02x max %03x%s\n" % \
			(" " * self.indent, cols[5], self.epaddr, self.type,
			 self.ival, self.attr, self.len, self.max, cols[0])


class UsbInterface:
	"Container for USB interface info"
	def __init__(self, parent = None, level = 1):
		self.parent = parent
		self.level = level
		self.fullpath = ""
		self.fname = ""
		self.iclass = 0
		self.isclass = 0
		self.iproto = 0
		self.noep = 0
		self.driver = ""
		self.devname = ""
		self.protoname = ""
		self.eps = []

	def read(self, fname):
		fullpath = ""
		if self.parent:
			fullpath += self.parent.fname + "/"
		fullpath += fname
		self.fullpath = fullpath
		self.fname = fname
		self.iclass = int(readattr(fullpath, "bInterfaceClass"), 16)
		self.isclass = int(readattr(fullpath, "bInterfaceSubClass"), 16)
		self.iproto = int(readattr(fullpath, "bInterfaceProtocol"), 16)
		self.noep = int(readattr(fullpath, "bNumEndpoints"))
		try:
			self.driver = readlink(fname, "driver")
			self.devname = find_dev(self.driver, fname)
		except:
			pass
		self.protoname = find_usb_class(self.iclass, self.isclass, self.iproto)
		if showeps:
			for epfnm in os.listdir(prefix + fullpath):
				if epfnm[:3] == "ep_":
					ep = UsbEndpoint(self, self.level+len(self.fname))
					ep.read(epfnm)
					self.eps.append(ep)

	def __str__(self):
		if self.noep == 1:
			plural = " "
		else:
			plural = "s"
		strg = "%-17s (IF) %02x:%02x:%02x %iEP%s (%s) %s%s %s%s%s\n" % \
			(" " * self.level+self.fname, self.iclass,
			 self.isclass, self.iproto, self.noep,
			 plural, self.protoname,
			 cols[3], self.driver,
			 cols[4], self.devname, cols[0])
		if showeps and self.eps:
			for ep in self.eps:
				strg += str(ep)
		return strg

class UsbDevice:
	"Container for USB device info"
	def __init__(self, parent = None, level = 0):
		self.parent = parent
		self.level = level
		self.fname = ""
		self.fullpath = ""
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

	def read(self, fname):
		self.fname = fname
		self.fullpath = fname
		self.iclass = int(readattr(fname, "bDeviceClass"), 16)
		self.isclass = int(readattr(fname, "bDeviceSubClass"), 16)
		self.iproto = int(readattr(fname, "bDeviceProtocol"), 16)
		self.vid = int(readattr(fname, "idVendor"), 16)
		self.pid = int(readattr(fname, "idProduct"), 16)
		try:
			self.name = readattr(fname, "manufacturer") + " " \
				  + readattr(fname, "product")
			#self.name += " " + readattr(fname, "serial")
			if self.name[:5] == "Linux":
				rx = re.compile(r"Linux [^ ]* (.hci_hcd) .HCI Host Controller")
				mch = rx.match(self.name)
				if mch:
					self.name = mch.group(1)

		except:
			pass
		if not self.name:
			self.name = find_usb_prod(self.vid, self.pid)
		# Some USB Card readers have a better name then Generic ...
		if self.name[:7] == "Generic":
			oldnm = self.name
			self.name = find_usb_prod(self.vid, self.pid)
			if not self.name:
				self.name = oldnm
		try:
			ser = readattr(fname, "serial")
			# Some USB devs report "serial" as serial no. suppress
			if (ser and ser != "serial"):
				self.name += " " + ser
		except:
			pass
		self.usbver = readattr(fname, "version")
		self.speed = readattr(fname, "speed")
		self.maxpower = readattr(fname, "bMaxPower")
		self.noports = int(readattr(fname, "maxchild"))
		try:
			self.nointerfaces = int(readattr(fname, "bNumInterfaces"))
		except:
			#print "ERROR: %s/bNumInterfaces = %s" % (fname,
			#		readattr(fname, "bNumInterfaces"))a
			self.nointerfaces = 0
		try:
			self.driver = readlink(fname, "driver")
			self.devname = find_dev(self.driver, fname)
		except:
			pass

	def readchildren(self):
		if self.fname[0:3] == "usb":
			fname = self.fname[3:]
		else:
			fname = self.fname
		for dirent in os.listdir(prefix + self.fname):
			if not dirent[0:1].isdigit():
				continue
			if os.access(prefix + dirent + "/bInterfaceClass", os.R_OK):
				iface = UsbInterface(self, self.level+1)
				iface.read(dirent)
				self.interfaces.append(iface)
			else:
				usbdev = UsbDevice(self, self.level+1)
				usbdev.read(dirent)
				usbdev.readchildren()
				self.children.append(usbdev)
		usbsortkey = lambda obj: [int(x) for x in re.split(r"[-:.]", obj.fname)]
		self.interfaces.sort(key=usbsortkey)
		self.children.sort(key=usbsortkey)

	def __str__(self):
		#buf = " " * self.level + self.fname
		if self.iclass == HUB_ICLASS:
			col = cols[2]
			if noemptyhub and len(self.children) == 0:
				return ""
			if nohub:
				buf = ""
		else:
			col = cols[1]
		if not nohub or self.iclass != HUB_ICLASS:
			if self.nointerfaces == 1:
				plural = " "
			else:
				plural = "s"
			buf = "%-16s %s%04x:%04x%s %02x %s%5sMBit/s %s %iIF%s (%s%s%s)" % \
				(" " * self.level + self.fname,
				 cols[1], self.vid, self.pid, cols[0],
				 self.iclass, self.usbver, self.speed, self.maxpower,
				 self.nointerfaces, plural, col, self.name, cols[0])
			#if self.driver != "usb":
			#	buf += " %s" % self.driver
			if self.iclass == HUB_ICLASS and not showhubint:
				buf += " %shub%s\n" % (cols[2], cols[0])
			else:
				buf += "\n"
				if showeps:
					ep = UsbEndpoint(self, self.level + len(self.fname))
					ep.read("ep_00")
					buf += str(ep)
				if showint:
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
		if dirent[0:3] != "usb":
			continue
		usbdev = UsbDevice(None, 0)
		usbdev.read(dirent)
		usbdev.readchildren()
		print(usbdev, end="")

def main(argv):
	global showint, showhubint, noemptyhub, nohub
	global cols, usbids, showeps
	use_colors = None

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

	for opt in optlist:
		if opt[0] in {"-h", "--help"}:
			usage()
			sys.exit(0)
		if opt[0] in {"-i", "--interfaces"}:
			showint = True
			continue
		if opt[0] in {"-I", "--hub-interfaces"}:
			showint = True
			showhubint = True
			continue
		if opt[0] in {"-u", "--hide-empty-hubs"}:
			noemptyhub = True
			continue
		if opt[0] in {"-U", "--hide-hubs"}:
			noemptyhub = True
			nohub = True
			continue
		if opt[0] in {"-c", "--color"}:
			use_colors = True
			continue
		if opt[0] in {"-C", "--no-color"}:
			use_colors = False
			continue
		if opt[0] == "-w":
			print("warning: option", opt[0], "is no longer supported", file=sys.stderr)
			continue
		if opt[0] in {"-f", "--usbids-path"}:
			usbids = opt[1]
			continue
		if opt[0] in {"-e", "--endpoints"}:
			showeps = True
			continue

	if args:
		print("Error: excess args %s ..." % args[0], file=sys.stderr)
		sys.exit(2)

	if use_colors is None:
		use_colors = (os.environ.get("TERM", "dumb") != "dumb") and sys.stdout.isatty()
	if use_colors:
		cols = (norm, bold, red, green, amber, blue)

	parse_usb_ids()
	read_usb()

if __name__ == "__main__":
	main(sys.argv)

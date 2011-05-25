# -*- mode: python -*-
# Simple command line interface to Windows XP Firewall.
from __future__ import print_function
import sys
import win32api as Api
import win32con as Con

REG_PATH = "SYSTEM\\CurrentControlSet\\Services\\SharedAccess\\Parameters\\FirewallPolicy\\StandardProfile\\GloballyOpenPorts\\List"

Machine = None

def load_name(ptr):
	resfile, resid = ptr[1:].split(",")
	resid = int(resid)
	resh = Api.LoadLibraryEx(resfile, 0, Con.LOAD_LIBRARY_AS_DATAFILE)
	val = Api.LoadString(resh, -resid, 1024)
	Api.FreeLibrary(resh)
	return val

def parse_port(val):
	a, b = val.lower().split("/")
	try:
		a = int(a)
	except ValueError:
		try:
			b = int(b)
		except ValueError:
			raise ValueError("Port must be an integer")
		else:
			port, proto = b, a
	else:
		port, proto = a, b
	
	if not 1 < port < 65535:
		raise ValueError("Port must be in range 1-65535")
	if proto not in ("tcp", "udp"):
		raise ValueError("Protocol must be TCP or UDP")
		
	return port, proto

def unpack_port(val):
	port, proto, scope, mode, name = val.split(":", 4)
	port = int(port)
	enabled = (mode == "Enabled")
	return [port, proto, scope, enabled, name]

def pack_port(port, proto, scope=None, enabled=False, name=""):
	port = str(port)
	proto = proto.upper()
	if scope and name:
		if scope == "local":
			scope = "LocalSubNet"
		return ":".join((port, proto, scope, "Enabled" if enabled else "Disabled", name))
	else:
		return ":".join((port, proto))

class reg_connect():
	def __init__(self, machine=None):
		if machine:
			if not machine.startswith("\\\\"):
				machine = "\\\\%s" % machine
			self.hkey = Api.RegConnectRegistry(machine, Con.HKEY_LOCAL_MACHINE)
		else:
			self.hkey = Api.RegOpenKeyEx(Con.HKEY_LOCAL_MACHINE, None, 0, Con.KEY_ALL_ACCESS)
		self.subkey = Api.RegOpenKeyEx(self.hkey, REG_PATH, 0, Con.KEY_ALL_ACCESS)
	
	def __del__(self):
		Api.RegCloseKey(self.subkey)
		Api.RegCloseKey(self.hkey)

def fw_query_ports(reg):
	i = 0
	while True:
		try:
			value, data, type = Api.RegEnumValue(reg.subkey, i)
		except Api.error:
			break
		else:
			yield unpack_port(data)
			i += 1

def fw_add_port(reg, port, proto, scope, enable, name):
	if not scope:
		scope = "*"
	value = pack_port(port, proto)
	data = pack_port(port, proto, scope, enable, name)
	Api.RegSetValueEx(reg.subkey, value, None, Con.REG_SZ, data)

def fw_del_port(reg, port, proto):
	value = pack_port(port, proto)
	Api.RegDeleteValue(reg.subkey, value)

def fw_enable_port(reg, port, proto, enable=True):
	value = pack_port(port, proto)
	try:
		data, value_type = Api.RegQueryValueEx(reg.subkey, value)
	except Api.error as e:
		raise
	data = unpack_port(data)
	data[3] = enable
	Api.RegSetValueEx(reg.subkey, value, None, value_type, pack_port(*data))

def query(machine=None):
	reg = reg_connect(machine)
	entries = list(fw_query_ports(reg))
	entries.sort(key=lambda e: e[0])
	entries.sort(key=lambda e: e[1])
	for port, proto, scope, enabled, name in entries:
		if name.startswith("@"):
			name = load_name(name)
		print(" %1s %-4s %-5d %s" % ("*" if enabled else "", proto, port, name))

def enable(port, proto, machine=None):
	reg = reg_connect(machine)
	fw_enable_port(reg, port, proto, True)

def disable(port, proto, machine=None):
	reg = reg_connect(machine)
	fw_enable_port(reg, port, proto, False)

machine = None
cmd = "ls"
args = []

try:
	if sys.argv[1].startswith("\\\\"):
		machine = sys.argv.pop(1)
	cmd = sys.argv.pop(1)
	args = sys.argv[1:]
except IndexError:
	pass

if cmd == "help":
	print("Usage:")
	print("\tfw [\\\\machine] ls")
	print("\tfw [\\\\machine] enable|disable <proto>/<port> ...")
	print("\tfw [\\\\machine] add <proto>/<port> <name> [<scope>]")
	print("\tfw [\\\\machine] del <proto>/<port>")
elif cmd == "ls":
	query(machine)
elif cmd in ("enable", "disable"):
	reg = reg_connect(machine)
	for arg in args:
		port, proto = parse_port(arg)
		fw_enable_port(reg, port, proto, cmd == "enable")
elif cmd == "add":
	reg = reg_connect(machine)
	port, proto = parse_port(args[0])
	name = args[1]
	try:
		scope = args[2]
	except IndexError:
		scope = "*"
	fw_add_port(reg, port, proto, scope, True, name)
elif cmd == "del":
	reg = reg_connect(machine)
	for arg in args:
		port, proto = parse_port(arg)
		fw_del_port(reg, port, proto)
else:
	print("Unknown command '%s'" % cmd, file=sys.stderr)

# -*- mode: python -*-
# Simple command line interface to Windows XP Firewall.
from __future__ import print_function
import sys
from libnullroute.windows.firewall import Firewall

def usage():
	print("Usage:")
	print("\tfw [\\\\machine] ls")
	print("\tfw [\\\\machine] enable|disable <proto>/<port> ...")
	print("\tfw [\\\\machine] add <proto>/<port> <name> [<scope>]")
	print("\tfw [\\\\machine] del <proto>/<port>")

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

def Main():
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
		return usage()
	elif cmd == "ls":
		fw = Firewall(machine)
		entries = list(fw.ports.enumerate())
		entries.sort(key=lambda e: e[fw.ports.POS_PORT])
		entries.sort(key=lambda e: e[fw.ports.POS_PROTO])
		for port, proto, scope, enabled, name in entries:
			print(" %1s %-4s %5d %s" % ("*" if enabled else "", proto, port, name))
	elif cmd == "ls-apps":
		fw = Firewall(machine)
		entries = list(fw.apps.enumerate())
		for exepath, scope, enabled, name in entries:
			print(" %1s %s" % ("*" if enabled else "", exepath))
	elif cmd in ("enable", "disable"):
		fw = Firewall(machine)
		for arg in args:
			port, proto = parse_port(arg)
			fw.ports.enable(port, proto, cmd == "enable")
	elif cmd == "add":
		try:
			port, proto = parse_port(args[0])
			name = args[1]
		except IndexError:
			return usage()
		try:
			scope = args[2]
		except IndexError:
			scope = "*"
		fw = Firewall(machine)
		fw.ports[port, proto] = (scope, True, name)
	elif cmd == "del":
		fw = Firewall(machine)
		for arg in args:
			port, proto = parse_port(arg)
			del fw.ports[port, proto]
	else:
		print("Unknown command '%s'" % cmd, file=sys.stderr)

Main()

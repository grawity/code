#!/usr/bin/env python
# update-etchosts - update fake-dynamic /etc/hosts entries
import os
import socket
import sys

if sys.platform == "win32":
	HOSTS_PATH = os.path.expandenv("%SystemRoot%/System32/drivers/etc/hosts")

def is_local_name(name):
	local_domains = (".home",
			".nullroute.eu.org",)
	return any(name.endswith(i) for i in local_domains)

def is_local_addr(af, addr):
	prefixes = ("192.168.",)
	return any(addr.startswith(i) for i in prefixes)

def resolve_addr(name):
	gai = socket.getaddrinfo(name, None)
	for af, sol, proto, canon, sa in gai:
		if af in (socket.AF_INET, socket.AF_INET6):
			addr = sa[0]
		else:
			continue
		print "... %s" % addr
		if is_local_addr(af, addr) and not is_local_name(name):
			continue
		else:
			yield addr

def update_names(input):
	fixup = False
	pastnames = set()
	for line in input:
		if line == "#begin fixup":
			fixup = True
			yield line
		elif line == "#end fixup":
			fixup = False
			yield line
		elif not line or line.startswith("#"):
			yield line
		elif fixup:
			names = line.split()
			addr = names.pop(0)
			name = names[0]
			if name in pastnames:
				continue
			print "Updating %r" % name
			for addr in resolve_addr(name):
				yield "\t".join([addr]+names)
			pastnames.update(names)
		else:
			yield line

# Stage 1: remove old entries to avoid breaking getaddrinfo

input = ""
output = ""

print "Reading current hosts file"

fixup = False
for line in open(HOSTS_PATH, "r"):
	input += line
	line = line.rstrip('\r\n')
	if line == "#begin fixup":
		fixup = True
	elif line == "#end fixup":
		fixup = False
	elif fixup:
		pass
	else:
		output += line + "\n"

try:
	print "Temporarily removing dynamic entries"
	open(HOSTS_PATH, "w").write(output)
except:
	print "Failed. Recovering old file"
	open(HOSTS_PATH, "w").write(input)
	raise

# Stage 2: add new entries

output = ""

try:
	print "Updating entries"
	for line in update_names(input.splitlines()):
		output += line + "\n"
except:
	print "Failed. Recovering old file"
	open(HOSTS_PATH, "w").write(input)
	raise
else:
	print "Writing new hosts file"
	open(HOSTS_PATH, "w").write(output)

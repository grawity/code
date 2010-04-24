#!/usr/bin/python
# encoding=utf-8
# hostalias v1.0 - adds host alias support to PuTTY
# (c) 2010 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
from __future__ import print_function
import os, sys, subprocess
from os.path import expanduser, expandvars
import fnmatch

#alias_file = expanduser("~/.hostaliases")
alias_file = expandvars("${AppData}/hostaliases.txt")

"""
Usage:
	hostalias [puttyargs] [user@]host[:port]
	
	Both <user> or <port>, when specified, override those from hostaliases.

hostalias syntax:

	entry: <aliases> = [<user>@][<hostmask>][:<port>] [puttyargs]

	Aliases are comma-separated. Spaces are ignored. Hosts are lowercase'd.
	
	If <hostmask> starts with a period ".", then it is _appended_ to input.
	
	All asterisks "*" in <hostmask> are replaced with input.
	
	<hostmask> is not required if user and/or port are specified. (If you only
	want to set puttyargs but keep user@host:port, set host to *)
	
	Aliases can be chained but not looped.

Example hostalias entries:

	# host 'box' becomes 'homebox.dyndns.org'
	box = homebox.dyndns.org

	# hosts 'foo' and 'bar' get '.example.com' appended
	# user is set to 'joeuser' unless overriden by commandline
	foo, bar = joeuser@.example.com

	# host 'mail' becomes 'adm-mail.example.com'
	# host 'log' becomes 'adm-log.example.com'
	# port is set to 21032 unless overriden by commandline
	mail, log = adm-*.example.com:21032
"""

# Split [user@]host[:port]
def split_address(address):
	group, user, host, port = None, None, address.lower(), None
	if "/" in host:
		group, host = host.split("/", 1)
	if "@" in host:
		user, host = host.split("@", 1)
	if ":" in host:
		host, port = host.split(":", 1)
	try:
		port = int(port)
	except TypeError:
		port = None
	
	return group, user, host, port

class addr():
	def gethost(self, input):
		if self.host == "" or self.host is None:
			return ""
		elif self.host[0] == ".":
			return input + self.host
		elif "*" in target.host:
			return self.host.replace("*", input)
		else:
			return self.host

	def __init__(s, address=None):
		if address is None:
			s.group, s.user, s.host, s.port = None, None, None, None
		else:
			s.group, s.user, s.host, s.port = split_address(address)
		s.opts = []
	
	def __repr__(s):
		r = ", ".join(["%s=%s" % (k, repr(v)) for k, v in s.__dict__.items() if v is not None and v != ""])
		return "<address" + (("(%s)" % r) if len(r) > 0 else "") + ">"
	
	def __iadd__(self, other):
		if other.user and not self.user:
			self.user = other.user
		if other.host and not self.host:
			self.host = other.host
		if other.port and not self.port:
			self.port = other.port
		if len(other.opts):
			self.opts += other.opts
		return self
		
	def __ior__(self, other):
		if other.user and not self.user:
			self.user = other.user
		if other.host:
			if self.host:
				self.host = expand_host(template=other.host, host=self.host)
			else:
				self.host = other.host
		if other.port and not self.port:
			self.port = other.port
		if len(other.opts):
			self.opts += other.opts
		return self

# Parse hostaliases.txt into %aliases
def read_aliases(file):
	alias_map = {}
	for line in open(file, "r"):
		line = line.strip()
		if line == "" or line[0] == "#": continue
		
		keys, target = line.split("=", 1)
		keys = keys.lower().replace(" ", "").split(",")
		
		target_address = addr()
		
		for i in target.split():
			if i.startswith("-"):
				target_address.opts.append(i)
			else:
				target_address.user, target_address.host, target_address.port = split_address(i)[1:]
				if target_address.host.startswith("."):
					target_address.host = "*" + target_address.host
		
		for k in keys:
			if k not in alias_map:
				alias_map[k] = addr()
			alias_map[k] += target_address
	return alias_map

## expand_host("*.foo.com", "foobox")
def expand_host(template, host):
	print("expand_host(", template, ",", host, ")")
	if template == "" or template is None:
		return host
	elif "*" in template:
		return template.replace("*", host)
	else:
		return template

def match(string, mask):
	mask = mask.lower() if mask else "*"
	if string is None or len(string) == 0:
		return True
	else:
		string = string.lower()
		return fnmatch.fnmatchcase(string, mask)

def matchint(integer, mask):
	print("matchint(", integer, mask, ")")
	if mask == integer or mask == "*" or not mask:
		return True
	else:
		return False

def find_aliases(input):
	print("find_aliases(", input, ")")
	for alias, target in aliases.items():
		alias = addr(alias)
		if alias.group in (input.group, None) and match(input.user, alias.user) and match(input.host, alias.host) and matchint(input.port, alias.port):
			yield alias, target

if len(sys.argv) >= 2:
	input = sys.argv.pop()
	input = addr(input)
	extargs = sys.argv[1:]
else:
	print("Usage: %s [puttyargs] [user@]host[:port]"
		% os.path.basename(sys.argv[0]),
		file=sys.stderr)
	sys.exit(2)

aliases = read_aliases(alias_file)

final = addr()
checked = []

for alias, next in find_aliases(input):
	print("* matched", alias)
	print("  target:", next)
	input |= next

input.group = None
print(input)

while input not in checked:
	for alias, next in find_aliases(input):
		print("* matched", alias)
		print("  target:", next)
		input |= next
	checked.append(input)

final = input

args = ["putty", final.host]
args += final.opts
if final.user != None:
	args += ["-l", final.user]
if final.port != None:
	args += ["-P", str(final.port)]

print("exec:", repr(args))
subprocess.Popen(args)

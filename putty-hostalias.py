#!/usr/bin/python
# encoding=utf-8
# hostalias v1.0 - adds host alias support to PuTTY
# (c) 2010 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
from __future__ import print_function
import os, sys, subprocess
from os.path import expanduser, expandvars

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

class addr():
	@classmethod
	def split(self, input):
		user, host, port = None, input, None
		if "@" in host:
			user, host = host.split("@", 2)
		if ":" in host:
			host, port = host.split(":", 2)
		
		try:
			port = int(port)
		except TypeError:
			port = None
		
		return user, host, port
	
	def __init__(s, input):
		s.user, s.host, s.port = addr.split(input)
		s.opts = []

def read_aliases(file):
	aliases = {}
	fh = open(file, "r")
	for line in fh:
		line = line.strip()
		if line == "" or line[0] == "#":
			continue
		else:
			alias, target = line.split("=", 1)
			alias = alias.lower().replace(" ", "").split(",")
			opts = target.split()
			target = opts.pop(0).lower()
			for i in alias:
				aliases[i] = addr(target)
				aliases[i].opts = opts[:]
	fh.close()
	return aliases

if len(sys.argv) >= 2:
	host = sys.argv.pop()
	extargs = sys.argv[1:]
else:
	print("Usage: %s [puttyargs] [user@]host[:port]"
		% os.path.basename(sys.argv[0]),
		file=sys.stderr)
	sys.exit(2)

user, host, port = addr.split(host)

aliases = read_aliases(alias_file)

# resolve alias
antiloop = []
while host not in antiloop:
	host = host.lower()
	antiloop.append(host)
	if host in aliases:
		target = aliases[host]
		
		if target.host == "":
			pass
		elif target.host[0] == ".":
			host = host + target.host
		elif "*" in target.host:
			host = target.host.replace("*", host)
		else:
			host = target.host
		
		if user == None and target.user != None:
			user = target.user
		if port == None and target.port != None:
			port = target.port

		extargs += target.opts

if host in antiloop[:-1]:
	antiloop.append(t_host)
	print("Loop detected:", " -> ".join(antiloop))

pArgs = ["putty", host]
pArgs += extargs
if user != None:
	pArgs += ["-l", user]
if port != None:
	pArgs += ["-P", str(port)]

#print("exec:", repr(pArgs))
subprocess.Popen(pArgs)

#!/usr/bin/python
# vim: fileencoding=utf-8

# checks for duplicate known_hosts entries

# (c) 2009 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

import os

dedup = False
knownhosts_path = os.path.expanduser("~/.ssh/known_hosts")

keys = {}

fh = open(knownhosts_path, "r")
# check for duplicates
for line in fh:
	line = line.strip()
	if line == "" or line[0] == "#":
		continue
	
	host, type, key = line.split(" ")
	if (type, key) in keys:
		keys[(type, key)].append(host)
	else:
		keys[(type, key)] = [ host ]

# print results
if dedup:
	for entry in keys:
		type, key = entry
		hosts = ",".join(keys[entry])
		print " ".join([hosts, type, key])
else:
	for entry in keys:
		hosts = keys[entry]
		type, key = entry
		if len(hosts) > 1:
			print "Key [%(shortkey)s] has %(count)d entries:" % {
				"shortkey": type + " ..." + key[-15:],
				"count": len(hosts)
			}
			print "\t%s" % "\n\t".join(hosts)

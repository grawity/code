#!/usr/bin/env python3
from __future__ import print_function
import sys

"""
usage: python3 unbrick-server.py libc.so libwhatever.so | nc -vvlp 1111
"""

for fn in sys.argv[1:]:
	fh = open(fn, "rb")
	bad = [ord(c) for c in "'% \\\t\n"]
	print(fn)
	while True:
		buf = fh.read(1024)
		if not buf:
			break
		buf = [ord(c) for c in buf]
		sz = "'%s'" % "".join(["\\%03o" % c \
					if c in bad or c < 32 or c >= 127 \
					else chr(c)
					for c in buf])
		print(len(sz), sz)
	print("0")
print("end.")

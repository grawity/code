#!/usr/bin/env python2
# encoding: utf-8

# Screen dump tool for Sony-Ericsson phones.
# (c) 2010 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

import sys
import serial
from PIL import Image

"""
Todo: add multiple screen support

>>> AT*ZIPI=?
--- *ZIPI: (0 - 319), (0 - 239), (0 - 239), 16, 0
--- OK
>>> AT*ZISI=?
--- *ZISI: 320, 240, 16, 0
--- OK
"""

def put(x):
	sys.stdout.write(x)
	sys.stdout.flush()

def load_screen(serFh):
	input, lastin = [], ""
	
	print "Capturing screen (eta 10 seconds)"
	serFh.write("AT*ZISI\r\n")
	while True:
		line = ser.readline()
		if not line:
			break

		line = line.strip()
		if line == "":
			pass
		elif line == "ERROR":
			put("X")
			return False
		elif line == "OK":
			put(")")
			break
		elif line.startswith("AT"):
			put("(")
		elif line.startswith("*"):
			put("*")
			if line.startswith("*ZISI:"):
				if len(lastin) > 0:
					input.append(parse_input(lastin))
				lastin = line
		else:
			put(".")
			lastin += line
	put("\n")
	input.append(parse_input(lastin))
	
	return input

def parse_input(line):
	magic = "*ZISI: "
	if not line.startswith(magic):
		raise ValueError, repr(line)
	line = line[len(magic):].decode("hex")
	
	# split into pixels and convert ARGB -> RGBA
	return [line[i+1:i+4] + line[i] for i in xrange(0, len(line), 4)]

def flatten(seq):
	result = []
	for el in seq:
		if hasattr(el, "__iter__") and not isinstance(el, basestring):
			result.extend(flatten(el))
		else:
			result.append(el)
	return result

try:
	port, output_file = sys.argv[1:]
except IndexError:
	print >> sys.stderr, "Usage: grabscreen.py <port> <imagefile>"
	sys.exit(2)

print "Connecting to %(port)s" % dict(port=port)

ser = serial.Serial(port, 921600, timeout=5)
pixels = load_screen(ser)
ser.close()

if pixels is False:
	print >> sys.stderr, "AT*ZISI returned error"
	sys.exit(1)

size = len(pixels[0]), len(pixels)
print "Loaded image: %dx%d" % size

def store_image(pixels, output_file):
	buffer = ""
	for row in pixels:
		for pix in row:
			buffer += pix
	# buffer = "".join(flatten(pixels))

	img = Image.fromstring("RGBA", size, buffer, "raw", "RGBA", 0, 1)
	img.save(output_file)

def store_raw(pixels, output_file):
	img = open(output_file, "wb")
	for row in pixels:
		for pix in row:
			img.write(pix)
	img.close()

store_image(pixels, output_file)
print "Saved to %s" % output_file

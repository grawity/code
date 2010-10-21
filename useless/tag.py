#!/usr/bin/env python2
# A simple mutagen wrapper
# Does mostly the same (and less) than "mid3v2" in mutagen distribution.

import sys
import getopt
try:
	#import mutagen
	from mutagen.mp3 import MP3
	from mutagen.easyid3 import EasyID3
except ImportError:
	print >> sys.stderr, "The mutagen library is not installed."
	sys.exit(42)

try:
	shortopts, longopts = "", (
		"album=",
		"artist=",
		"date=",
		"genre=",
		"title=",
		
		"rewrite",
		)
	options, files = getopt.gnu_getopt(sys.argv[1:], shortopts, longopts)
except getopt.GetoptError as e:
	print >> sys.stderr, "Error:", e
	sys.exit(2)

changes = []
actions = []

for opt, value in options:
	opt = opt.strip("-")
	value = unicode(value, "utf-8") if len(value) > 0 else None
	if opt == "rewrite":
		actions += (("rewrite"))
	else:
		if opt == "date" and value is not None:
			try:
				int(value)
			except ValueError:
				print >> sys.stderr, "Error: %(opt)s must be an integer" % locals()
				sys.exit(1)
		changes.append((opt, value))

for file in files:
	#tag = EasyID3(file)
	tag = MP3(file, ID3=EasyID3)
	
	if len(changes)+len(actions) > 0:
		for key, value in changes:
			if value == "":
				value = None
			
			if key in tag:
				old = ", ".join(tag[key])
			else:
				old = "(none)"
			
			if value is None and key in tag:
				print "[%(key)s] deleting \"%(old)s\"" % locals()
				del tag[key]
			elif value is None:
				pass
			else:
				print "[%(key)s] \"%(old)s\" -> \"%(value)s\"" % locals()
				tag[key] = [value]
		
		for k in actions:
			action = k.pop(0)
			if action == "rewrite":
				pass # will do it anyway
		
		tag.save(v1=0) # kill ID3v1
	else:
		print "== %s" % file
		print tag.pprint()
		#for key in ("title", "artist", "album"):
		#	if key in tag:
		#		value = ", ".join(tag[key])
		#		print "%-10s: %s" % (key, value)

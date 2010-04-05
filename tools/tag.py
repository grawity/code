#!/usr/bin/python
# A simple mutagen wrapper

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
	shortopts, longopts = "A:a:d:g:t:", (
		"album=",
		"artist=",
		"date=",
		"genre=",
		"title=",
		)
	options, files = getopt.gnu_getopt(sys.argv[1:], shortopts, longopts)
except getopt.GetoptError as e:
	print >> sys.stderr, "Error:", e
	sys.exit(2)

changes = []


optmap = dict(
	A="album", a="artist", d="date", g="genre", t="title"
)
for opt, value in options:
	opt = opt.strip("-")
	opt = optmap.get(opt, opt)
	
	value = unicode(value, "utf-8")
	if opt == "date" and len(value):
		try:
			int(value)
		except ValueError:
			print >> sys.stderr, "Error: %(opt)s must be an integer" % locals()
			sys.exit(1)
	changes.append((opt, value))

for file in files:
	#tag = EasyID3(file)
	tag = MP3(file, ID3=EasyID3)
	
	if len(changes) > 0:
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
		tag.save(v1=0) # kill ID3v1
	else:
		print "== %s" % file
		print tag.pprint()
		#for key in ("title", "artist", "album"):
		#	if key in tag:
		#		value = ", ".join(tag[key])
		#		print "%-10s: %s" % (key, value)
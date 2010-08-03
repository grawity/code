#!/usr/bin/python
# Read and write lyrics tags.
import sys

import getopt

try:
	import mutagen.mp3, mutagen.id3
except ImportError:
	print >> sys.stderr, "This script requires Mutagen."
	sys.exit(42)

def usage():
	print >> sys.stderr, """\
import: lyrics -i [-f lyricfile] audiofile
export: lyrics -e [-f lyricfile] audiofile
remove: lyrics -x audiofile
"""
	sys.exit(2)

# Turn off textmode stdio, otherwise CR CR LF is written
if sys.platform == "win32":
	from os import O_BINARY
	import msvcrt
	for fd in (sys.stdin, sys.stdout, sys.stderr):
		msvcrt.setmode(fd.fileno(), O_BINARY)

def write_id3(file, lyrics):
	tag = mutagen.mp3.MP3(file)
	atom = u"USLT::'eng'"
	if lyrics is None:
		if atom in tag:
			del tag[atom]
	else:
		tag[atom] = mutagen.id3.USLT()
		tag[atom].text = lyrics
		tag[atom].encoding = 1
		tag[atom].lang = "eng"
		tag[atom].desc = u""
	if verbose:
		print >> sys.stderr, "Writing %s" % file
	tag.save()

def read_id3(file):
	tag = mutagen.mp3.MP3(file)
	try:
		return tag[u"USLT::'eng'"].text
	except KeyError:
		return None

mode = None
lyricsfile = None
verbose = False

try:
	options, audiofiles = getopt.gnu_getopt(sys.argv[1:], "ef:iovx")
except getopt.GetoptError as e:
	print >> sys.stderr, "Error:", e
	usage()

for opt, value in options:
	if   opt == "-e": mode = "output"
	elif opt == "-f": lyricsfile = value
	elif opt == "-i": mode = "input"
	elif opt == "-o": mode = "output"
	elif opt == "-v": verbose = True
	elif opt == "-x": mode = "kill"

if len(audiofiles) < 1:
	print >> sys.stderr, "Error: no mp3 files specified"
	usage()

if mode == "input":
	if lyricsfile is None:
		f = sys.stdin
	else:
		f = open(lyricsfile, "r")

	lyrics = f.read().decode("utf-8")

	for file in audiofiles:
		write_id3(file, lyrics)
		
elif mode == "output":
	if lyricsfile is None:
		f = sys.stdout
	else:
		f = open(lyricsfile, "w")

	for file in audiofiles:
		lyrics = read_id3(file)
		if lyrics is None: continue

		sys.stdout.write(lyrics.encode("utf-8"))

elif mode == "kill":
	for file in audiofiles:
		write_id3(file, None)

else:
	usage()

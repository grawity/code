#!/usr/bin/python2 -u
# Read and write lyrics tags.
from __future__ import print_function
import sys
import getopt

try:
	import mutagen.mp3, mutagen.id3
except ImportError:
	print >> sys.stderr, "The mutagen library is not installed."
	sys.exit(42)

def to_crlf(s):
	return s.replace("\r\n", "\n").replace("\n", "\r\n")

def from_crlf(s):
	return s.replace("\r\n", "\n")

# Turn off text mode stdio on Windows (otherwise it writes CR CR LF)
if sys.platform == "win32":
	import os, msvcrt
	for fd in (sys.stdin, sys.stdout, sys.stderr):
		msvcrt.setmode(fd.fileno(), os.O_BINARY)

def write_id3(file, lyrics):
	tag = mutagen.mp3.MP3(file)
	atom = u"USLT::'eng'"
	if lyrics is None and atom in tag:
		del tag[atom]
	else:
		tag[atom] = mutagen.id3.USLT()
		tag[atom].text = lyrics
		tag[atom].encoding = 1
		tag[atom].lang = "eng"
		tag[atom].desc = u""
	tag.save()

def read_id3(file):
	tag = mutagen.mp3.MP3(file)
	try:
		return tag[u"USLT::'eng'"].text
	except KeyError:
		return None

mode = "output"
lyricsfile = None

try:
	options, files = getopt.gnu_getopt(sys.argv[1:], "f:iox")
except getopt.GetoptError as e:
	print(e, file=sys.stderr)
	sys.exit(2)

for opt, value in options:
	if   opt == "-i": mode = "input"
	elif opt == "-o": mode = "output"
	elif opt == "-x": mode = "kill"
	elif opt == "-f": lyricsfile = value

if mode == "input":
	if lyricsfile is None:
		f = sys.stdin
	else:
		f = open(lyricsfile, "r")
	lyrics = to_crlf(f.read().decode("utf-8"))
	for file in files:
		write_id3(file, lyrics)
elif mode == "output":
	if lyricsfile is None:
		f = sys.stdout
	else:
		f = open(lyricsfile, "w")
	for file in files:
		lyrics = read_id3(file)
		if lyrics:
			lyrics = from_crlf(lyrics)
			sys.stdout.write(lyrics.encode("utf-8"))
elif mode == "kill":
	for file in files:
		write_id3(file, None)

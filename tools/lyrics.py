#!/usr/bin/python
# Read and write lyrics tags.
import sys
import getopt
try:
	import mutagen
except ImportError:
	print >> sys.stderr, "The mutagen library is not installed."
	sys.exit(42)

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

shortopts = "i" "o" "x" "f:"
longopts = []
try:
	options, files = getopt.gnu_getopt(sys.argv[1:], shortopts, longopts)
except getopt.GetoptError as e:
	print >> sys.stderr, "Error:", e
	sys.exit(2)

mode = "output"
lyricsfile = None

for opt, value in options:
	if   opt == "-i": mode = "input"
	elif opt == "-o": mode = "output"
	elif opt == "-x": mode = "kill"
	elif opt == "-f": lyricsfile = value

if mode == "input":
	# input: write lyrics into file
	if lyricsfile is not None:
		sys.stdin = open(lyricsfile, "r")
	lyrics = sys.stdin.read().decode("utf-8")
	
	for file in files:
		write_id3(file, lyrics)
		
elif mode == "output":
	# output: read lyrics to stdout
	if lyricsfile is not None:
		sys.stdout = open(lyricsfile, "w")
		
	for file in files:
		lyrics = read_id3(file)
		if lyrics is None:
			continue
		for line in lyrics.splitlines():
			print line.strip().encode("utf-8")
			
elif mode == "kill":
	# kill: remove lyrics
	for file in files:
		write_id3(file, None)

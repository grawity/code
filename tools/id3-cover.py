#!/usr/bin/python
import sys
from mutagen import mp3, id3
shift = lambda: sys.argv.pop(1)

def filename_to_mime(path):
	return {
		"png": "image/png",
		"jpeg": "image/jpeg",
		"jpg": "image/jpeg",
		}.get(path.split(".")[-1], "image/jpeg")

def export_cover(audiofile, imagefile):
	audio = mp3.MP3(audiofile)
	if "APIC:" not in audio:
		print >> sys.stderr, "No APIC frame found"
		return False
	
	if imagefile.endswith("."):
		imagefile += {
			"image/png": "png",
			"image/jpeg": "jpeg",
			}.get(audio["APIC:"].type, "jpeg")
	
	with open(imagefile, "wb") as image:
		image.write(audio["APIC:"].data)
	
	print "Stored to %s" % imagefile
	return True

def import_cover(imagefile, audiofile):
	TYPE_FRONT_COVER = 3
	ENC_UTF8 = 3
	
	audio = mp3.MP3(audiofile)
	imagedata = open(imagefile, "rb").read()
	imagemime = filename_to_mime(imagefile)
	audio.tags.add(id3.APIC(data=imagedata, mime=imagemime, type=TYPE_FRONT_COVER,
		desc="", encoding=ENC_UTF8))
	audio.save()

def nuke_cover(audiofile):
	audio = mp3.MP3(audiofile)
	del audio["APIC:"]
	audio.save()

try:
	action = shift()
except IndexError:
	action = "-o"

audiofile = shift()
imagefile = shift()

if action == "-i":
	import_cover(imagefile, audiofile)
elif action == "-o" or action == "-e":
	export_cover(audiofile, imagefile)
elif action == "-x":
	nuke_cover(audiofile)
else:
	print >> sys.stderr, "Usage:"
	print >> sys.stderr, "\t(import to tag)   cover -i foo.mp3 foo.jpg"
	print >> sys.stderr, "\t(export to file)  cover -o foo.mp3 foo.jpg"
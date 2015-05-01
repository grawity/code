from __future__ import print_function

schemes = {
	"tango": [
		# colors in ANSI order
		# normal: 0-7, bold: 1-15
		0x000000,	0xcc0000,	0x4e9a06,	0xc4a000,
		0x3465a4,	0x75507b,	0x06989a,	0xd3d7cf,
		0x555753,	0xef2929,	0x8ae234,	0xfce94f,
		0x729fcf,	0xad7fa8,	0x34e2e2,	0xeeeeec,
	],
	"xterm": [
		0x000000,	0xcc0000,	0x4e9a06,	0xc4a000,
		0x3465a4,	0x75507b,	0x06989a,	0xd3d7cf,
		0x555753,	0xef2929,	0x8ae234,	0xfce94f,
		0x729fcf,	0xad7fa8,	0x34e2e2,	0xeeeeec,
	],
}

def rgb(color):
	return color >> 16, (color >> 8) & 0xFF, color & 0xFF

def WindowsConsole(scheme):
	# color table entry => ANSI color
	order = [0, 4, 2, 6, 1, 5, 3, 7]
	print("Windows Registry Editor Version 5.00")
	print("")
	print("[HKEY_CURRENT_USER\\Console]")
	for i in range(16):
		r, g, b = rgb(scheme[order[i % 8] + 8*int(i >= 8)])
		print("\"ColorTable%02d\"=dword:%08x" % (i, b<<16|g<<8|r))

def PuTTY(scheme):
	# fg, bold fg, bg, bold bg, cursor fg, cursor bg, ANSI
	extra = [7, 15, 0, 0, 7, 0]
	print("Windows Registry Editor Version 5.00")
	print("")
	print("[HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\Default Settings]")
	for i in range(22):
		j = extra[i] if i<6 else i-6
		r, g, b = rgb(scheme[j])
		print("\"Colour%d\"=\"%d,%d,%d\"" % (i, r, g, b))

def XTerm(scheme):
	for i in range(16):
		r, g, b = rgb(scheme[i])
		print("XTerm*color%d:\t#%04x%04x%04x" % (i, r<<8|r, g<<8|g, b<<8|b))

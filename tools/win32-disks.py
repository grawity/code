#!/usr/bin/env python
# A df-like utility for Windows
# dependencies: pywin32

import os, sys
import ctypes
try:
	import win32api, win32con, win32file
except ImportError:
	print "This script requires PyWin32."

kernel32 = ctypes.windll.kernel32

drivetypes = {
	win32con.DRIVE_UNKNOWN: "unknown",
	win32con.DRIVE_NO_ROOT_DIR: "not a volume",
	win32con.DRIVE_REMOVABLE: "removable",
	win32con.DRIVE_FIXED: "fixed",
	win32con.DRIVE_REMOTE: "network",
	win32con.DRIVE_CDROM: "CD",
	win32con.DRIVE_RAMDISK: "RAM disk",
	-1: "mapped",
	-2: "no media",
}

def prettySize(bytes):
	if bytes is None: return None
	q = "kMGTPEY"
	size = float(bytes)
	l = -1
	while size >= 1000:
		size /= 1024.
		l += 1
	return "%.2f %sB" % (size, q[l] if l >= 0 else "")

def EnumVolumes():
	buf = ctypes.create_unicode_buffer(256)
	volumes = []
	
	h = kernel32.FindFirstVolumeW(buf, ctypes.sizeof(buf))
	if h >= 0: volumes.append(buf.value)
	else: return None
	
	res = True
	while res:
		res = kernel32.FindNextVolumeW(h, buf, ctypes.sizeof(buf))
		if res: volumes.append(buf.value)
		else: break
	
	kernel32.FindVolumeClose(h)
	return volumes

def GetPathNamesForVolume(volume):
	buf = ctypes.create_unicode_buffer(4096)
	length = ctypes.c_int32()
	if kernel32.GetVolumePathNamesForVolumeNameW(ctypes.c_wchar_p(volume), buf, ctypes.sizeof(buf), ctypes.pointer(length)):
		pathnames = []
		offset = 0
		while offset < length:
			path = ctypes.wstring_at(ctypes.addressof(buf) + offset*2)
			if path:
				pathnames.append(path)
				offset += len(path)+1
			else:
				break
		return pathnames
	else:
		raise Error

def EnumMountPoints(root):
	buf = ctypes.create_unicode_buffer(256)
	mounts = []

	h = kernel32.FindFirstVolumeMountPointW(ctypes.c_wchar_p(root), buf, ctypes.sizeof(buf))
	if h >= 0: mounts.append(buf.value)
	else: return mounts
	
	res = True
	while res:
		res = kernel32.FindNextVolumeMountPointW(h, buf, ctypes.sizeof(buf))
		if res: mounts.append(buf.value)
		else: break
	
	kernel32.FindVolumeMountPointClose(h)
	return mounts

def IsVolumeReady(root):
	try: win32api.GetVolumeInformation(root)
	except: return False
	else: return True

def GetDosDevice(dev):
	return win32file.QueryDosDevice(dev[0:2]) if len(dev) <= 3 else None

def IsMappedDevice(dev):
	return GetDosDevice(dev).startswith("\\??\\")

def GetMountVolume(path):
	return win32file.GetVolumeNameForVolumeMountPoint(path)

LINE_FORMAT = "%-5s %-12s %-17s %10s %10s"
header = LINE_FORMAT % ("path", "label", "type", "free", "total")
print header
print "-"*len(header)

Letters = [unicode(s) for s in win32api.GetLogicalDriveStrings().strip("\0").split("\0")]
Letters.sort()

Drives = {}
Maps = {}
Volumes = {}

Printed = []

for volGuid in EnumVolumes():
	names = GetPathNamesForVolume(volGuid)
	ready = IsVolumeReady(volGuid)
	Volumes[volGuid] = {"pathnames": names, "ready": ready}
del names, ready

for letter in Letters:
	if IsMappedDevice(letter):
		target = GetDosDevice(letter).strip("\0").split("\0")[0]
		if target.startswith("\\??\\"):
			target = target[len("\\??\\"):]
		Maps[letter] = target
	else:
		Drives[letter] = GetMountVolume(letter)

for letter in Letters:
	isMapped = letter in Maps
	
	if isMapped:
		target = Maps[letter]
		type = -1
		free, total, diskfree = win32api.GetDiskFreeSpaceEx(letter)
	
	else:
		root = Drives[letter]
		
		if root in Printed:
			continue
		Printed.append(root)
		
		pathnames = Volumes[root]["pathnames"][:]
		isReady = Volumes[root]["ready"]
		
		if isReady:
			type = win32file.GetDriveType(root)
			info = win32api.GetVolumeInformation(root)
			label, filesystem = info[0], info[4]
		else:
			type, label, filesystem = -2, "", None
			
		if isReady and type != win32con.DRIVE_REMOTE:
			free, total, diskfree = win32api.GetDiskFreeSpaceEx(root)
		else:
			free, total, diskfree = None, None, None
	
	if filesystem:
		strtype = "%s (%s)" % (drivetypes[type], filesystem)
	else:
		strtype = drivetypes[type]
	
	print LINE_FORMAT % (
		letter,
		label or "(unnamed)",
		strtype,
		prettySize(free),
		prettySize(total),
	)
	
	if isMapped:
		print "%-5s ==> %s" % ("", target)
	else:
		pathnames.remove(letter)
		for path in pathnames:
			print "%-5s <-- %s" % ("", path)

for root in Volumes.keys():
	if root in Printed:
		continue
	
	pathnames = Volumes[root]["pathnames"][:]
	isReady = Volumes[root]["ready"]
	
	if isReady:
		type = win32file.GetDriveType(root)
		info = win32api.GetVolumeInformation(root)
		label, filesystem = info[0], info[4]
	else:
		type, label, filesystem = -2, "", None
	
	if isReady and type != win32con.DRIVE_REMOTE:
		free, total, diskfree = win32api.GetDiskFreeSpaceEx(root)
	else:
		free, total, diskfree = None, None, None
	
	if filesystem:
		strtype = "%s (%s)" % (drivetypes[type], filesystem)
	else:
		strtype = drivetypes[type]
	
	print LINE_FORMAT % (
		"*",
		label or "(unnamed)",
		strtype,
		prettySize(free),
		prettySize(total),
	)
	for path in pathnames:
		print "%-5s <-- %s" % ("", path)

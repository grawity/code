#!python.exe
# A df-like utility for Windows
# depends: pywin32

import os, sys
import ctypes
import win32api, win32con, win32file
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
	if len(dev) > 3: # mountpoints
		return None
	return win32file.QueryDosDevice(dev[0:2])

def IsMappedDevice(dev):
	return not GetDosDevice(dev).startswith("\\Device\\")

def EnumMappedDevices():
	letters = []
	for l in win32api.GetLogicalDriveStrings().strip("\0").split("\0"):
		if IsMappedDevice(l): letters.append(l)
	return letters

def GetMountVolume(path):
	return win32file.GetVolumeNameForVolumeMountPoint(path)

LineFormat = "%-5s %-12s %10s %10s"
header = LineFormat % ("path", "type", "free", "total")
print header, "\n", "-"*len(header)

DriveLetters = [unicode(s) for s in win32api.GetLogicalDriveStrings().strip("\0").split("\0")]

Drives = []
Maps = []
MountPoints = []
Volumes = {}
for v in EnumVolumes():
	Volumes[v] = []
#VolLetters = {}
Printed = []

for letter in DriveLetters:
	if not IsVolumeReady(letter): continue
	if IsMappedDevice(letter):
		Maps.append(letter)
	else:
		Drives.append(letter)
		#VolLetters[GetMountVolume(letter)] = letter
		dest = GetMountVolume(letter)
		#Volumes[dest].append(letter)
		for mountpoint in EnumMountPoints(letter):
				mountpoint = letter + mountpoint
				dest = GetMountVolume(mountpoint)
				Volumes[dest].append(mountpoint)

#Volumes = EnumVolumes()
#Volumes.sort(key=lambda vol: VolLetters.get(vol, "\uFFFF"))

for letter in DriveLetters:
	isReady = IsVolumeReady(letter)
	isMapped = IsMappedDevice(letter)
	
	#if not isReady: continue
	
	if IsMappedDevice(letter):
		target = GetDosDevice(letter).strip("\0").split("\0")[0]
		type = -1
		free, total, diskfree = win32api.GetDiskFreeSpaceEx(letter)
		
	else:
		volume = GetMountVolume(letter)
		if volume in Printed: continue
		else: Printed.append(volume)
		
		if isReady:
			type = win32file.GetDriveType(volume)
		else:
			type = -2
	
		if isReady and type != win32con.DRIVE_REMOTE:
			free, total, diskfree = win32api.GetDiskFreeSpaceEx(letter)
		else:
			free, total, diskfree = None, None, None

	print LineFormat % (letter,
		"(%s)" % drivetypes[type],
		prettySize(free),
		prettySize(total)
	)
	
	if isMapped:
		print "%-5s ==> %s" % ("", target)
	else:
		for path in Volumes[volume]:
			print "%-5s <-- %s" % ("", path)

for volume in EnumVolumes():
	if volume in Printed:
		continue
	
	isReady = IsVolumeReady(volume)
	if isReady:
		type = win32file.GetDriveType(volume)
	else:
		type = -2

	if isReady and type != win32con.DRIVE_REMOTE:
		free, total, diskfree = win32api.GetDiskFreeSpaceEx(volume)
	else:
		free, total, diskfree = None, None, None

	print LineFormat % ("*",
		"(%s)" % drivetypes[type],
		prettySize(free),
		prettySize(total)
	)

	for path in Volumes[volume]:
		print "%-5s <-- %s" % ("", path)

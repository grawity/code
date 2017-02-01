#!python
# a df-like utility for Windows

import os, sys

import win32api     as Api
import win32file    as File
import win32net     as Net

try:
    from win32con import *
except ImportError:
    DRIVE_UNKNOWN     = 0
    DRIVE_NO_ROOT_DIR = 1
    DRIVE_REMOVABLE   = 2
    DRIVE_FIXED       = 3
    DRIVE_REMOTE      = 4
    DRIVE_CDROM       = 5
    DRIVE_RAMDISK     = 6
    MAX_PATH          = 260
    SEM_FAILCRITICALERRORS = 1

from ctypes import *
kernel32 = windll.kernel32
kernel32.SetErrorMode(SEM_FAILCRITICALERRORS)

drivetypes = {
    DRIVE_UNKNOWN:      "unknown",
    DRIVE_NO_ROOT_DIR:  "not a volume",
    DRIVE_REMOVABLE:    "removable",
    DRIVE_FIXED:        "fixed",
    DRIVE_REMOTE:       "network",
    DRIVE_CDROM:        "CD",
    DRIVE_RAMDISK:      "RAM disk",

    -1:                 "mapped",
    -2:                 "no media",
}

def prettySize(bytes):
    if bytes is None: return "-"
    size = float(bytes)
    l = -1
    while size >= 1000:
        size /= 1024.
        l += 1
    return "%.2f %sB" % (size, "kMGTPEY"[l] if l >= 0 else "")

def EnumVolumes():
    buf = create_unicode_buffer(256)
    volumes = []

    h = kernel32.FindFirstVolumeW(buf, sizeof(buf))
    if h:
        yield buf.value
        while kernel32.FindNextVolumeW(h, buf, sizeof(buf)):
            yield buf.value
        kernel32.FindVolumeClose(h)

def wszarray_to_list(array):
    output = []
    offset = 0
    while offset < sizeof(array):
        sz = wstring_at(addressof(array) + offset*2)
        if sz:
            output.append(sz)
            offset += len(sz)+1
        else:
            break
    return output

def GetPathNamesForVolume(volume):
    buf = create_unicode_buffer(4096)
    length = c_int32()
    if kernel32.GetVolumePathNamesForVolumeNameW(c_wchar_p(volume), buf, sizeof(buf), byref(length)):
        return wszarray_to_list(buf)
    else:
        raise OSError

def QueryDosDevice(dev):
    dev = dev[:dev.index(":")+1]
    target = File.QueryDosDevice(dev)
    return target.split("\0")[0]

def GetMountVolume(path):
    volume_name = create_unicode_buffer(64)
    res = kernel32.GetVolumeNameForVolumeMountPointW(
        c_wchar_p(path), volume_name, sizeof(volume_name))
    if res:
        return volume_name.value

def GetCanonicalName(disk):
    target = QueryDosDevice(disk)
    if target is None:
        print("QueryDosDevice(%r) is %r" % (letter, target))
        return None
    elif target.startswith("\\??\\"):
        # `subst`-mapped disk
        if target.startswith("\\??\\"):
            target = target[len("\\??\\"):]
        return target, False
    elif target.startswith("\\Device\\LanmanRedirector\\"):
        # network disk
        return Net.NetUseGetInfo(None, disk[0]+":")["remote"], True
    elif target.startswith("UNC\\"):
        # `subst`-mapped network disk
        return target[4:], True
    else:
        return GetMountVolume(letter), False

def GetDriveType(root):
    return kernel32.GetDriveTypeW(c_wchar_p(root))

def GetVolumeInformation(root):
    volume_name = create_unicode_buffer(MAX_PATH+1)
    serial_number = c_int32()
    max_component_length = c_int32()
    flags = c_int32()
    fs_name = create_unicode_buffer(MAX_PATH+1)
    if kernel32.GetVolumeInformationW(c_wchar_p(root), volume_name,
            sizeof(volume_name), byref(serial_number), byref(max_component_length),
            byref(flags), fs_name, sizeof(fs_name)):
        return (volume_name.value, serial_number.value, byref(max_component_length),
            flags.value, fs_name.value)
    else: raise OSError

def IsVolumeReady(root):
    try: GetVolumeInformation(root)
    except: return False
    else: return True

def GetLogicalDriveStrings():
    return Api.GetLogicalDriveStrings().split("\0")[:-1]

LINE_FORMAT = "%-5s %-16s %-17s %10s %10s %5s"
header = LINE_FORMAT % ("path", "label", "type", "size", "free", "used")
print(header)
print("-"*len(header))

Letters = GetLogicalDriveStrings()
Letters.sort()

Drives = {}
Maps = {}
Volumes = {}

Printed = []

Volumes = {guid: {"pathnames": GetPathNamesForVolume(guid),
                  "ready": IsVolumeReady(guid)} for guid in EnumVolumes()}

DosDevices = {}
for letter in Letters:
    target = DosDevices[letter] = QueryDosDevice(letter)
    if target is None:
        print("QueryDosDevice(%r) is %r" % (letter, target))
    elif target.startswith("\\??\\"):
        # `subst`-mapped disk
        #target = target[:target.index("\0")]
        if target.startswith("\\??\\"):
            target = target[len("\\??\\"):]
        Maps[letter] = target
    elif target.startswith("\\Device\\LanmanRedirector\\"):
        # network disk
        Maps[letter] = GetCanonicalName(letter)
        Drives[letter] = Maps[letter]
        pass
    elif target.startswith("UNC\\"):
        # `subst`-mapped network disk
        #Maps[letter] =
        pass
    else:
        Drives[letter] = GetMountVolume(letter)

for letter in Letters:
    isMapped = letter in Maps

    if isMapped:
        target = Maps[letter]
        type = -1
        free, total, diskfree = Api.GetDiskFreeSpaceEx(letter)
        used = 100 - (100*diskfree/total)

    else:
        root = Drives[letter]

        if root in Printed:
            continue
        Printed.append(root)

        pathnames = Volumes[root]["pathnames"][:]
        isReady = Volumes[root]["ready"]

        if isReady:
            type = GetDriveType(root)
            info = GetVolumeInformation(root)
            label, filesystem = info[0], info[4]
        else:
            type, label, filesystem = -2, "", None

        if isReady and type != DRIVE_REMOTE:
            free, total, diskfree = Api.GetDiskFreeSpaceEx(root)
            used = 100 - (100*diskfree/total)
        else:
            free, total, diskfree, used = None, None, None, None

    if filesystem:
        strtype = "%s (%s)" % (drivetypes[type], filesystem)
    else:
        strtype = drivetypes[type]

    print(LINE_FORMAT % (
        letter,
        label or "(unnamed)",
        strtype,
        prettySize(total),
        prettySize(diskfree),
        "%d%%" % used if used is not None else "-",
    ))

    if isMapped:
        print("%-5s ==> %s" % ("", target))
    else:
        pathnames.remove(letter)
        for path in pathnames:
            print("%-5s <-- %s" % ("", path))

for root in Volumes.keys():
    if root in Printed:
        continue

    pathnames = Volumes[root]["pathnames"][:]
    isReady = Volumes[root]["ready"]

    if isReady:
        type = GetDriveType(root)
        info = GetVolumeInformation(root)
        label, filesystem = info[0], info[4]
    else:
        type, label, filesystem = -2, "", None

    if isReady and type != DRIVE_REMOTE:
        free, total, diskfree = Api.GetDiskFreeSpaceEx(root)
        used = 100 - (100*diskfree/total)
    else:
        free, total, diskfree, used = None, None, None, None

    if filesystem:
        strtype = "%s (%s)" % (drivetypes[type], filesystem)
    else:
        strtype = drivetypes[type]

    print(LINE_FORMAT % (
        "*",
        label or "(unnamed)",
        strtype,
        prettySize(total),
        prettySize(diskfree),
        "%d%%" % used if used is not None else "-",
    ))
    for path in pathnames:
        print("%-5s <-- %s" % ("", path))

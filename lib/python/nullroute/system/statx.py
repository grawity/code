import ctypes
import ctypes.util

AT_FDCWD            = -100

AT_SYMLINK_NOFOLLOW = 0x0100
AT_NO_AUTOMOUNT     = 0x0800
AT_EMPTY_PATH       = 0x1000

AT_STATX_FORCE_SYNC = 0x2000
AT_STATX_DONT_SYNC  = 0x4000

STATX_TYPE          = 0x0001
STATX_MODE          = 0x0002
STATX_NLINK         = 0x0004
STATX_UID           = 0x0008
STATX_GID           = 0x0010
STATX_ATIME         = 0x0020
STATX_MTIME         = 0x0040
STATX_CTIME         = 0x0080
STATX_INO           = 0x0100
STATX_SIZE          = 0x0200
STATX_BLOCKS        = 0x0400
STATX_BASIC_STATS   = 0x07ff
STATX_BTIME         = 0x0800
STATX_ALL           = 0x0fff

STATX_ATTR_COMPRESSED   = 0x00000004
STATX_ATTR_IMMUTABLE    = 0x00000010
STATX_ATTR_APPEND       = 0x00000020
STATX_ATTR_NODUMP       = 0x00000040
STATX_ATTR_ENCRYPTED    = 0x00000800
STATX_ATTR_AUTOMOUNT    = 0x00001000

class repr_trait():
    def __repr__(self):
        return "<%s(%s)>" % (self.__class__.__name__,
                             ", ".join(["%s=%r" % (n, getattr(self, n))
                                        for n, t in self._fields_]))

class struct_statx_timestamp(ctypes.Structure, repr_trait):
    _fields_ = (
        ("tv_sec",              ctypes.c_int64),
        ("tv_nsec",             ctypes.c_uint32),
        ("__reserved",          ctypes.c_int32),
    )

class struct_statx(ctypes.Structure, repr_trait):
    _fields_ = (
        ("stx_mask",            ctypes.c_uint32),
        ("stx_blksize",         ctypes.c_uint32),
        ("stx_attributes",      ctypes.c_uint64),
        ("stx_nlink",           ctypes.c_uint32),
        ("stx_uid",             ctypes.c_uint32),
        ("stx_gid",             ctypes.c_uint32),
        ("stx_mode",            ctypes.c_uint16),
        ("__spare0",            ctypes.c_uint16 * 1),
        ("stx_ino",             ctypes.c_uint64),
        ("stx_size",            ctypes.c_uint64),
        ("stx_blocks",          ctypes.c_uint64),
        ("stx_attributes_mask", ctypes.c_uint64),
        ("stx_atime",           struct_statx_timestamp),
        ("stx_btime",           struct_statx_timestamp),
        ("stx_ctime",           struct_statx_timestamp),
        ("stx_mtime",           struct_statx_timestamp),
        ("stx_rdev_major",      ctypes.c_uint32),
        ("stx_rdev_minor",      ctypes.c_uint32),
        ("stx_dev_major",       ctypes.c_uint32),
        ("stx_dev_minor",       ctypes.c_uint32),
        ("__spare2",            ctypes.c_uint64 * 14),
    )

def _get_libc_fn(fname, argtypes, restype):
    soname = ctypes.util.find_library("c")
    func = ctypes.cdll[soname][fname]
    func.argtypes = argtypes
    func.restype = restype
    return func

_libc_statx = None

def statx(fileno, path, flags, mask):
    global _libc_statx
    if not _libc_statx:
        _libc_statx = ctypes.cdll[ctypes.util.find_library("c")]["statx"]

    buf = struct_statx()
    r = _libc_statx(ctypes.c_int(fileno),
                    ctypes.c_char_p(path.encode()),
                    ctypes.c_int(flags),
                    ctypes.c_uint(mask),
                    ctypes.byref(buf))

    e = ctypes.get_errno()
    # TODO: how do I make errno actually work and be non-zero
    if r == 0:
        return buf
    else:
        raise OSError(e, "statx failed for %r" % path)

if __name__ == "__main__":
    import sys
    for path in sys.argv[1:]:
        print("===", path, "===")
        buf = statx(AT_FDCWD, path, 0, STATX_ALL)
        for n, t in buf._fields_:
            print(n, "=", getattr(buf, n))

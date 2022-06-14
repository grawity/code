import ctypes
import ctypes.util
import enum

AT_FDCWD = -100

class AtFlag(enum.IntFlag):
    AT_SYMLINK_NOFOLLOW = 0x0100
    AT_NO_AUTOMOUNT     = 0x0800
    AT_EMPTY_PATH       = 0x1000
    AT_STATX_FORCE_SYNC = 0x2000
    AT_STATX_DONT_SYNC  = 0x4000

AT_SYMLINK_NOFOLLOW     = AtFlag.AT_SYMLINK_NOFOLLOW
AT_NO_AUTOMOUNT         = AtFlag.AT_NO_AUTOMOUNT
AT_EMPTY_PATH           = AtFlag.AT_EMPTY_PATH
AT_STATX_FORCE_SYNC     = AtFlag.AT_STATX_FORCE_SYNC
AT_STATX_DONT_SYNC      = AtFlag.AT_STATX_DONT_SYNC

class StatxMask(enum.IntFlag):
    # Corresponds to data items STATX_* (except STATX_ATTR_*)
    TYPE        = 0x0001
    MODE        = 0x0002
    NLINK       = 0x0004
    UID         = 0x0008
    GID         = 0x0010
    ATIME       = 0x0020
    MTIME       = 0x0040
    CTIME       = 0x0080
    INO         = 0x0100
    SIZE        = 0x0200
    BLOCKS      = 0x0400
    BASIC_STATS = 0x07ff
    BTIME       = 0x0800
    ALL         = BASIC_STATS | BTIME
    MNT_ID      = 0x1000

STATX_TYPE              = StatxMask.TYPE
STATX_MODE              = StatxMask.MODE
STATX_NLINK             = StatxMask.NLINK
STATX_UID               = StatxMask.UID
STATX_GID               = StatxMask.GID
STATX_ATIME             = StatxMask.ATIME
STATX_MTIME             = StatxMask.MTIME
STATX_CTIME             = StatxMask.CTIME
STATX_INO               = StatxMask.INO
STATX_SIZE              = StatxMask.SIZE
STATX_BLOCKS            = StatxMask.BLOCKS
STATX_BASIC_STATS       = StatxMask.BASIC_STATS
STATX_BTIME             = StatxMask.BTIME
STATX_ALL               = StatxMask.ALL
STATX_MNT_ID            = StatxMask.MNT_ID

class StatxAttr(enum.IntFlag):
    # Corresponds to flags STATX_ATTR_*
    COMPRESSED  = 0x00000004
    IMMUTABLE   = 0x00000010
    APPEND      = 0x00000020
    NODUMP      = 0x00000040
    ENCRYPTED   = 0x00000800
    AUTOMOUNT   = 0x00001000
    MOUNT_ROOT  = 0x00002000
    VERITY      = 0x00100000
    DAX         = 0x00200000

STATX_ATTR_COMPRESSED   = StatxAttr.COMPRESSED
STATX_ATTR_IMMUTABLE    = StatxAttr.IMMUTABLE
STATX_ATTR_APPEND       = StatxAttr.APPEND
STATX_ATTR_NODUMP       = StatxAttr.NODUMP
STATX_ATTR_ENCRYPTED    = StatxAttr.ENCRYPTED
STATX_ATTR_AUTOMOUNT    = StatxAttr.AUTOMOUNT
STATX_ATTR_MOUNT_ROOT   = StatxAttr.MOUNT_ROOT
STATX_ATTR_VERITY       = StatxAttr.VERITY
STATX_ATTR_DAX          = StatxAttr.DAX

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
        ("stx_mnt_id",          ctypes.c_uint64),
        ("__spare23",           ctypes.c_uint64 * 13),
    )

def _get_libc_fn(fname, argtypes, restype):
    soname = ctypes.util.find_library("c")
    func = ctypes.CDLL(soname, use_errno=True)[fname]
    func.argtypes = argtypes
    func.restype = restype
    return func

_libc = None

def statx(fileno, path, flags, mask):
    global _libc

    if not _libc:
        _libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)

    buf = struct_statx()

    r = _libc.statx(ctypes.c_int(fileno),
                    ctypes.c_char_p(path.encode()),
                    ctypes.c_int(flags),
                    ctypes.c_uint(mask),
                    ctypes.byref(buf))
    if r != 0:
        raise OSError(ctypes.get_errno(), "statx failed for %r" % path)

    return buf

if __name__ == "__main__":
    import sys
    for path in sys.argv[1:]:
        print("===", path, "===")
        buf = statx(AT_FDCWD, path, 0, STATX_ALL)
        for n, t in buf._fields_:
            v = getattr(buf, n)
            if n.startswith("__spare"):
                continue
            elif n == "stx_mask":
                print(n, "=", v, "(", StatxMask(v), ")")
            elif n in {"stx_attributes", "stx_attributes_mask"}:
                print(n, "=", v, "(", StatxAttr(v), ")")
            else:
                print(n, "=", v)

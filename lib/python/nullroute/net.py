# Parts of code (c) Leonid Evdokimov <leon@darkk.net.ru>
# -- https://github.com/darkk/tcp_shutter/blob/master/tcp_shutter.py

import ctypes
import ctypes.util
import socket

libc = ctypes.CDLL(ctypes.util.find_library('c'), use_errno=True)
libc.getsockopt.argtypes = [ctypes.c_int, ctypes.c_int,
                            ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
libc.getsockname.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
libc.getpeername.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]

def ctypes_repr(self):
    return self.__class__.__name__ + '(' + ', '.join('%s=%s' % (f[0], getattr(self, f[0])) for f in self._fields_) + ')'

class sockaddr_in(ctypes.Structure):
    __repr__ = ctypes_repr
    _fields_ = (
        ('sin_family', ctypes.c_ushort),
        ('sin_port', ctypes.c_uint16),
        ('sin_addr', ctypes.c_uint8 * 4),
        ('sin_zero', ctypes.c_uint8 * (16 - 4 - 2 - 2)), # padding
    )
    def __str__(self):
        return '%s:%d' % (socket.inet_ntop(self.sin_family, ''.join(map(chr, self.sin_addr))), socket.ntohs(self.sin_port))


class sockaddr_in6(ctypes.Structure):
    __repr__ = ctypes_repr
    _fields_ = (
        ('sin6_family', ctypes.c_ushort),
        ('sin6_port', ctypes.c_uint16),
        ('sin6_flowinfo', ctypes.c_uint32),
        ('sin6_addr', ctypes.c_uint8 * 16),
        ('sin6_scope_id', ctypes.c_uint32)
    )
    def __str__(self):
        return '[%s]:%d' % (socket.inet_ntop(self.sin6_family, ''.join(map(chr, self.sin6_addr))), socket.ntohs(self.sin6_port))

class sockaddr_storage(ctypes.Union):
    __repr__ = ctypes_repr
    _fields_ = (
        ('v4', sockaddr_in),
        ('v6', sockaddr_in6),
    )

def get_x_name(fileno, libcfunc):
    sa = sockaddr_storage()
    sizeof = ctypes.c_size_t(ctypes.sizeof(sockaddr_storage))
    if libcfunc(fileno, ctypes.byref(sa), ctypes.byref(sizeof)) == 0:
        return (sa.v4 if sa.v4.sin_family == socket.AF_INET else sa.v6), None
    else:
        return None, ctypes.get_errno()

def getsockname(fileno):
    return get_x_name(fileno, libc.getsockname)

def getpeername(fileno):
    return get_x_name(fileno, libc.getpeername)

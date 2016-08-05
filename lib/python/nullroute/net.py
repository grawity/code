# Parts of code (c) Leonid Evdokimov <leon@darkk.net.ru>
# -- https://github.com/darkk/tcp_shutter/blob/master/tcp_shutter.py

import ctypes
import ctypes.util
import ipaddress
import os
import socket

libc = ctypes.CDLL(ctypes.util.find_library('c'), use_errno=True)
libc.getsockopt.argtypes = [ctypes.c_int, ctypes.c_int,
                            ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
libc.getsockname.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
libc.getpeername.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]

class sockaddr(ctypes.Structure):
    _fields_ = (
        ('sa_family',   ctypes.c_ushort),
        ('sa_data',     ctypes.c_uint8 * 14),
    )

    @property
    def family(self):
        return self.sa_family

class sockaddr_in(ctypes.Structure):
    _fields_ = (
        ('sin_family',  ctypes.c_ushort),
        ('sin_port',    ctypes.c_uint16),
        ('sin_addr',    ctypes.c_uint8 * 4),
        ('sin_zero',    ctypes.c_uint8 * (16 - 4 - 2 - 2)), # padding
    )

    @property
    def family(self):
        return self.sin_family

    @property
    def address(self):
        return ipaddress.IPv4Address(bytes(self.sin_addr))

    @property
    def port(self):
        return socket.ntohs(self.sin_port)

    def __str__(self):
        return "%s:%d" % (self.address, self.port)

    def __repr__(self):
        return "<sockaddr_in[address=%r, port=%r]>" % (self.address, self.port)

class sockaddr_in6(ctypes.Structure):
    _fields_ = (
        ('sin6_family',     ctypes.c_ushort),
        ('sin6_port',       ctypes.c_uint16),
        ('sin6_flowinfo',   ctypes.c_uint32),
        ('sin6_addr',       ctypes.c_uint8 * 16),
        ('sin6_scope_id',   ctypes.c_uint32),
    )

    @property
    def family(self):
        return self.sin6_family

    @property
    def address(self):
        return ipaddress.IPv6Address(bytes(self.sin6_addr))

    @property
    def port(self):
        return socket.ntohs(self.sin6_port)

    @property
    def flowinfo(self):
        return self.sin6_flowinfo

    @property
    def scope_id(self):
        return self.sin6_scope_id

    def __str__(self):
        if self.scope_id:
            return "[%s%%%d]:%d" % (self.address, self.scope_id, self.port)
        else:
            return "[%s]:%d" % (self.address, self.port)

    def __repr__(self):
        return "<sockaddr_in6[address=%r, port=%r, flowinfo=%r, scope_id=%r]>" \
                % (self.address, self.port, self.flowinfo, self.scope_id)

class sockaddr_union(ctypes.Union):
    _fields_ = (
        ('raw', sockaddr),
        ('v4', sockaddr_in),
        ('v6', sockaddr_in6),
    )

    @property
    def family(self):
        return self.raw.sa_family

def _get_socket_name(fileno, func):
    sa = sockaddr_union()
    size = ctypes.c_size_t(ctypes.sizeof(sockaddr_union))
    r = func(fileno, ctypes.byref(sa), ctypes.byref(size))
    if r == 0:
        if sa.family == socket.AF_INET:
            return sa.v4
        elif sa.family == socket.AF_INET6:
            return sa.v6
        else:
            return sa.raw
    else:
        errno = ctypes.get_errno()
        raise OSError(errno, os.strerror(errno))

def getsockname(fileno):
    return _get_socket_name(fileno, libc.getsockname)

def getpeername(fileno):
    return _get_socket_name(fileno, libc.getpeername)

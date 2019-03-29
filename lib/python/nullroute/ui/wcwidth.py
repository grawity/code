import ctypes
import ctypes.util

_libc_wcwidth = None
_libc_wcslen = None
_libc_wcswidth = None

def _get_libc_fn(fname, argtypes, restype):
    soname = ctypes.util.find_library("c")
    func = ctypes.cdll[soname][fname]
    func.argtypes = argtypes
    func.restype = restype
    return func

try:
    from wcwidth import wcwidth, wcswidth
except ImportError:
    _libc_wcwidth = _get_libc_fn("wcwidth",
                                 (ctypes.c_wchar,),
                                 ctypes.c_int)

    _libc_wcslen = _get_libc_fn("wcslen",
                                (ctypes.c_wchar_p,),
                                ctypes.c_size_t)

    _libc_wcswidth = _get_libc_fn("wcswidth",
                                  (ctypes.c_wchar_p, ctypes.c_size_t),
                                  ctypes.c_int)

    def wcwidth(char):
        return _libc_wcwidth(char)

    def wcswidth(string):
        return _libc_wcswidth(string, _libc_wcslen(string))

def wcpad(string, width):
    pad = abs(width) - wcswidth(string)
    if pad <= 0:
        return string
    elif width < 0:
        return string + " " * pad
    elif width > 0:
        return " " * pad + string

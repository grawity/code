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
    def wcwidth(char):
        global _libc_wcwidth
        if _libc_wcwidth is None:
            _libc_wcwidth = _get_libc_fn("wcwidth",
                                         (ctypes.c_wchar,),
                                         ctypes.c_int)
        return _libc_wcwidth(char)

    def wcswidth(string):
        global _libc_wcslen
        global _libc_wcswidth
        if _libc_wcslen is None:
            _libc_wcslen = _get_libc_fn("wcslen",
                                        (ctypes.c_wchar_p,),
                                        ctypes.c_size_t)
        if _libc_wcswidth is None:
            _libc_wcswidth = _get_libc_fn("wcswidth",
                                          (ctypes.c_wchar_p, ctypes.c_size_t),
                                          ctypes.c_int)
        return _libc_wcswidth(string, _libc_wcslen(string))

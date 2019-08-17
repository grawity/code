from ctypes import byref, POINTER, windll, WINFUNCTYPE
from ctypes.wintypes import BOOL, DWORD, HANDLE

# Based on:
# https://github.com/ytdl-org/youtube-dl/issues/15758#issuecomment-370630896

FILE_TYPE_CHAR = 0x0002
FILE_TYPE_REMOTE = 0x8000

STD_INPUT_HANDLE = -10
STD_OUTPUT_HANDLE = -11
STD_ERROR_HANDLE = -12

ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200
ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004

GetStdHandle = WINFUNCTYPE(HANDLE, DWORD)(("GetStdHandle", windll.kernel32))
GetConsoleMode = WINFUNCTYPE(BOOL, HANDLE, POINTER(DWORD))(("GetConsoleMode", windll.kernel32))
SetConsoleMode = WINFUNCTYPE(BOOL, HANDLE, DWORD)(("SetConsoleMode", windll.kernel32))

def enable_vt():
    h = GetStdHandle(STD_OUTPUT_HANDLE)
    if h is None or h == HANDLE(-1):
        return False
    mode = DWORD()
    if not GetConsoleMode(h, byref(mode)):
        return False
    if SetConsoleMode(h, mode.value | ENABLE_VIRTUAL_TERMINAL_PROCESSING):
        return True
    return False

import sys
import msvcrt

O_TEXT      = 0x4000  # file mode is text (translated)
O_BINARY    = 0x8000  # file mode is binary (untranslated)
O_WTEXT     = 0x10000 # file mode is UTF16 (translated)
O_U16TEXT   = 0x20000 # file mode is UTF16 no BOM (translated)
O_U8TEXT    = 0x40000 # file mode is UTF8  no BOM (translated)

def setconsmode(flag):
    for fh in (sys.stdin, sys.stdout, sys.stderr):
        msvcrt.setmode(fh.fileno(), flag)

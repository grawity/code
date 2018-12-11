import math
import os
import signal
import sys
try:
    from wcwidth import wcwidth, wcswidth
except ImportError:
    from nullroute.ui.wcwidth import wcwidth, wcswidth

_stderr_tty = None
_stderr_width = None

def stderr_tty():
    global _stderr_tty
    if _stderr_tty is None:
        _stderr_tty = os.isatty(sys.stderr.fileno())
    return _stderr_tty

def stderr_width():
    global _stderr_width
    if _stderr_width is None:
        if stderr_tty() and hasattr(os, "get_terminal_size"):
            _stderr_width = os.get_terminal_size(sys.stderr.fileno()).columns
        else:
            _stderr_width = 80
    return _stderr_width

def _handle_sigwinch(signum, stack):
    global _stderr_width
    if stderr_tty() and hasattr(os, "get_terminal_size"):
        _stderr_width = os.get_terminal_size(sys.stderr.fileno()).columns

def wctruncate(text, width=80):
    for i, c in enumerate(text):
        w = wcwidth(c)
        if w > 0:
            width -= w
        if width < 0:
            return text[:i]
    return text

def fmt_status(msg):
    return "\033[33m" + msg + "\033[m"

def print_status(*args, fmt=fmt_status, wrap=True):
    if not stderr_tty():
        return
    out = ""
    out += "\033[1G" # cursor to column 1
    #out += "\033[K" # erase to right (XXX: this was used in _truncated)
    out += "\033[0J" # erase below
    if args:
        msg = " ".join(args)
        msg = msg.replace("\n", " ")
        if wrap:
            out += fmt_status(msg)
            lines = math.ceil(wcswidth(msg) / stderr_width())
            if lines > 1:
                out += "\033[%dA" % (lines-1) # cursor up 1
        else:
            msg = wctruncate(msg, stderr_width())
            out += fmt_status(msg)
    sys.stderr.write(out)
    if not args:
        sys.stderr.flush()

def prompt(msg):
    print(msg, end="", flush=True)
    buf = sys.stdin.readline()
    return buf.strip() if buf else None

def confirm(msg):
    reply = prompt(msg)
    return reply.lower().startswith("y") if reply else False

def window_title(msg):
    if stderr_tty():
        print("\033]2;%s\007" % msg, end="", file=sys.stderr, flush=True)

class TableCell(object):
    def __init__(self, value, format=None):
        self.value = str(value)
        self.format = str(format or "")

class Table(object):
    def __init__(self):
        self.head = []
        self.rows = []

    def add_column(self, title):
        self.head.append(title)

    def add_row(self, cells):
        self.rows.append(cells)

    def print(self):
        rows = [self.head, *self.rows]
        widths = [0 for _ in rows[0]]
        for r, row in enumerate(rows):
            for c, cell in enumerate(row):
                widths[c] = max(widths[c], len(cell))
        for r, row in enumerate(rows):
            buf = ""
            for c, cell in enumerate(row):
                if c > 0:
                    buf += "  "
                buf += "%*s" % (-widths[c], cell)
            print(buf)
        pass

signal.signal(signal.SIGWINCH, _handle_sigwinch)

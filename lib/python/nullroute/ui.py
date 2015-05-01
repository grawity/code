import logging
import os
import sys

try:
    from wcwidth import wcwidth, wcswidth
except ImportError:
    wcwidth = lambda s: 1
    wcswidth = lambda s: len(s)

_stderr_tty = None
_stderr_width = None

_num_warnings = 0
_num_errors = 0

## regular log messages

try:
    _nested_env = int(os.environ.get("LVL"))
except:
    _nested_env = 0
os.environ["LVL"] = str(_nested_env + 1)

_debug_env = os.environ.get("DEBUG", "")

#logging.basicConfig(format="%(levelname)s: (%(module)s) %(message)s",
#                    level=(logging.DEBUG if _debug_env else logging.INFO))

def _log(prefix, msg, color="", fmt_prefix=None, fmt_color=None):
    fh = sys.stderr

    if getattr(fh, "isatty", lambda: True)():
        text = "\033[%sm%s:\033[m %s" % (color, prefix, msg)
    else:
        text = "%s: %s" % (prefix, msg)

    print(text, file=fh)

def debug(msg):
    if _debug_env:
        _log("debug", msg, "36")

def info(msg):
    _log("info", msg,
         color="1;32",
         fmt_prefix="~",
         fmt_color="1;32")

def warn(msg):
    global _num_warnings
    _num_warnings += 1
    _log("warning", msg, "1;33")

def err(msg):
    global _num_errors
    _num_errors += 1
    _log("error", msg, "1;31")
    return False

def die(msg):
    global _num_errors
    _num_errors += 1
    _log("fatal", msg, "1;31")
    sys.exit(1)

def exit():
    global _num_errors
    sys.exit(_num_errors > 0)

## status/progress messages

def isatty():
    global _stderr_tty
    if _stderr_tty is None:
        _stderr_tty = sys.stderr.isatty()
    return _stderr_tty

def ttywidth():
    global _stderr_width
    if _stderr_width is None:
        with os.popen("stty size", "r") as fh:
            line = fh.read().strip()
        rows, cols = line.split()
        _stderr_width = int(cols)
    return _stderr_width

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

def print_status(*args, fmt=fmt_status):
    if isatty() and not opts.verbose:
        msg = " ".join(args)
        msg = msg.replace("\n", " ")
        out = ""
        out += "\033[1G" # cursor to column 1
        out += "\033[0J" # erase below
        out += fmt_status(msg)
        lines = math.ceil(wcswidth(msg) / ttywidth())
        if lines > 1:
            out += "\033[%dA" % (lines-1) # cursor up 1
        sys.stderr.write(out)
        if not args:
            sys.stderr.flush()

def print_status_truncated(*args, fmt=fmt_status):
    if isatty() and not opts.verbose:
        msg = " ".join(args)
        msg = msg.replace("\n", " ")
        out = ""
        out += "\r\033[K"
        out += fmt_status(msg)
        sys.stderr.write(out)
        if not args:
            sys.stderr.flush()

def window_title(msg):
    if isatty():
        print("\033]2;%s\007" % msg, file=sys.stderr)

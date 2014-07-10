from __future__ import print_function
import sys

num_warnings = 0
num_errors = 0

def _log(prefix, msg, color=""):
    print("\033[%sm%s:\033[m %s" % (color, prefix, msg),
          file=sys.stderr)

def debug(msg):
    return _log("debug", msg, "36")

def warn(msg):
    global num_warnings
    num_warnings += 1
    return _log("warning", msg, "1;33")

def err(msg):
    global num_errors
    num_errors += 1
    return _log("error", msg, "1;31")

def die(msg):
    _log("fatal", msg, "1;31")
    sys.exit(1)

def exit():
    global num_errors
    sys.exit(1 if num_errors else 0)

from __future__ import print_function
import sys

def _log(prefix, msg, color=""):
    print("\033[%sm%s:\033[m %s" % (color, prefix, msg),
          file=sys.stderr)

def warn(msg):
    _log("warning", msg, "1;33")

def err(msg):
    _log("error", msg, "1;31")

def die(msg):
    err(msg)
    sys.exit(1)

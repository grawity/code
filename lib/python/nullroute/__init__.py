from __future__ import print_function
import sys
from nullroute.ui import (debug, warn, err, die)

arg0 = sys.argv[0].split("/")[-1]

def window_title(msg):
    print("\033]2;%s\007" % msg, file=sys.stderr)

def exit():
    global num_errors
    sys.exit(1 if num_errors else 0)

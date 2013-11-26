from __future__ import print_function
import sys

def warn(*args):
    print("\033[1;33mwarning:\033[m", " ".join(args), file=sys.stderr)

def err(*args):
    print("\033[1;31merror:\033[m", " ".join(args), file=sys.stderr)

def die(*args):
    err(*args)
    sys.exit(1)

#!/usr/bin/env python
import sys

def find_ranges(ints):
    lo = hi = None
    for x in ints:
        if lo is None:
            lo = hi = x
        elif x == hi + 1:
            hi = x
        else:
            yield (lo, hi)
            lo = hi = x
    if lo is not None:
        yield (lo, hi)

stdint = (int(s.strip(), 10) for s in sys.stdin)

for lo, hi in find_ranges(stdint):
    print(lo, "..", hi, "(%d)" % (hi-lo+1))

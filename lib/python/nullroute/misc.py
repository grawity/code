from .file import *
from .string import *

def chunk(vec, size):
    for i in range(0, len(vec), size):
        yield vec[i:i+size]

def flatten_dict(d):
    for k, v in d.items():
        yield k
        yield v

def uniq(items):
    seen = set()
    for item in items:
        if item not in seen:
            seen.add(item)
            yield item

import os
import time

from .string import *

def set_file_mtime(path, timestamp):
    if hasattr(path, "fileno"):
        path = path.fileno()
    os.utime(path, (time.time(), timestamp))

def get_file_attr(path, attr):
    try:
        if hasattr(path, "fileno"):
            path = path.fileno()
        value = os.getxattr(path, "user.%s" % attr)
        try:
            return value.decode("utf-8")
        except UnicodeDecodeError:
            return value
    except FileNotFoundError:
        raise
    except OSError:
        return None

def set_file_attr(path, attr, value):
    try:
        if hasattr(path, "fileno"):
            path = path.fileno()
        if hasattr(value, "encode"):
            value = value.encode("utf-8")
        if value:
            os.setxattr(path, "user.%s" % attr, value)
        else:
            os.removexattr(path, "user.%s" % attr)
    except FileNotFoundError:
        raise
    except OSError:
        return

def list_file_attrs(path):
    try:
        if hasattr(path, "fileno"):
            path = path.fileno()
        return [attr[5:] for attr in os.listxattr(path) if attr.startswith("user.")]
    except FileNotFoundError:
        raise
    except OSError:
        return []

def get_file_attrs(path, attrs=None):
    try:
        if not attrs:
            attrs = list_file_attrs(path)
        return {attr: get_file_attr(path, attr) for attr in attrs}
    except FileNotFoundError:
        raise
    except OSError:
        return {}

def set_file_attrs(path, attrs):
    try:
        for attr, value in attrs.items():
            set_file_attr(path, attr, value)
    except FileNotFoundError:
        raise
    except OSError:
        return

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

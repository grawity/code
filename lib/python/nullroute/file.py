import os
import time

XA_XDG_USER_COMMENT     = "xdg.comment"
XA_XDG_ORIGIN_URL       = "xdg.origin.url"
XA_XDG_REFERRER_URL     = "xdg.referrer.url"
XA_XDG_ROBOTS_INDEX     = "xdg.robots.index"
XA_XDG_ROBOTS_BACKUP    = "xdg.robots.backup"

XA_DC_TITLE         = "dublincore.title"
XA_DC_CREATOR       = "dublincore.creator"
XA_DC_SUBJECT       = "dublincore.subject"
XA_DC_DESCRIPTION   = "dublincore.description"
XA_DC_PUBLISHER     = "dublincore.publisher"
XA_DC_CONTRIBUTOR   = "dublincore.contributor"
XA_DC_DATE          = "dublincore.date"
XA_DC_TYPE          = "dublincore.type"
XA_DC_FORMAT        = "dublincore.format"
XA_DC_IDENTIFIER    = "dublincore.identifier"
XA_DC_SOURCE        = "dublincore.source"
XA_DC_LANGUAGE      = "dublincore.language"
XA_DC_RELATION      = "dublincore.relation"
XA_DC_COVERAGE      = "dublincore.coverage"
XA_DC_RIGHTS        = "dublincore.rights"

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

def digest_files(paths, digest="sha1"):
    import subprocess
    with subprocess.Popen(["%ssum" % digest, *paths],
                          stdout=subprocess.PIPE) as proc:
        return {k: v for (v, k)
                in [line.decode().rstrip("\n").split("  ", 1) for line
                    in proc.stdout]}

def hash_file(path, digest="sha1"):
    import hashlib
    h = getattr(hashlib, digest)()
    with open(path, "rb") as fh:
        buf = True
        buf_size = 4 * 1024 * 1024
        while buf:
            buf = fh.read(buf_size)
            h.update(buf)
    return h.hexdigest()

def compare_files(a, b):
    return (os.path.exists(a)
        and os.path.exists(b)
        and hash_file(a) == hash_file(b))

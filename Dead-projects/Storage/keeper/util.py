import os
import binascii

ZERO = "\0" * 20

KiB =   1 << 10
MiB = KiB << 10
GiB = MiB << 10

class KeeperError(Exception):
    pass

class DataCorruptionError(KeeperError):
    _fmt = "corrupted block %r (kind %r, %s)"

    def __init__(self, score, kind, reason):
        self.score    = score
        self.kind     = kind
        self.reason   = reason

        self.msg = self._fmt % (to_hex(score), kind, reason)
        self.args = [self.msg]

class HashMismatchError(DataCorruptionError):
    _fmt = "corrupted block %r (kind %r, real hash %r)"

    def __init__(self, score, kind, hash):
        self.score    = score
        self.kind     = kind
        self.hash     = hash

        self.msg = self._fmt % (to_hex(score), kind, to_hex(hash))
        self.args = [self.msg]

class SizeMismatchError(DataCorruptionError):
    _fmt = "corrupted block %r (kind %r, real size %d, expected %d)"

    def __init__(self, score, kind, real_size, want_size):
        self.score     = score
        self.kind      = kind
        self.real_size = real_size
        self.want_size = want_size

        self.msg = self._fmt % (to_hex(score), kind, real_size, want_size)
        self.args = [self.msg]

def to_hex(s: "bytes[]", bin=False) -> "bytes[]|str":
    h = binascii.b2a_hex(s)
    return h if bin else h.decode("utf-8")

def from_hex(s: "bytes[]") -> "bytes[]":
    return binascii.a2b_hex(s)

def to_str(s: "bytes[]") -> "str":
    return s.decode("utf-8")

def from_str(s: "str") -> "bytes[]":
    return s.encode("utf-8")

def mkdir_parents(path):
    head, tail = os.path.split(path)
    if head and not os.path.exists(head):
        mkdir_parents(head)
    if not os.path.exists(path):
        os.mkdir(path)

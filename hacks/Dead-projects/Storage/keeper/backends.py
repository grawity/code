import os
import sys
import hashlib

from util import *

class Backend(object):
    """ Abstract class for any storage backend. """

    blocksize = None

    def _make_header(self, kind: "str", size: "int") -> "header: bytes[]":
        return ("%s %d\n" % (kind, size)).encode("utf-8")

    def hash(self, block: "bytes[]", kind: "str") -> "score: bytes[]":
        h = hashlib.sha1()
        h.update(self._make_header(kind, len(block)))
        h.update(block)
        return h.digest()

    @property
    def hashlen(self):
        return hashlib.sha1().digest_size

    def put(self, block: "bytes[]", kind: "str") -> "score: bytes[]":
        raise NotImplementedError

    def get(self, score: "bytes[]") -> ("block: bytes[]", "kind: str"):
        raise NotImplementedError

    def kind(self, score: "bytes[]") -> "kind: str":
        raise NotImplementedError

    def contains(self, score: "bytes[]") -> "bool":
        raise NotImplementedError

    def discard(self, score: "bytes[]") -> "void":
        raise NotImplementedError

class FileBackend(Backend): # {{{
    def __init__(self, path):
        self.path = path

    def _hash_to_path(self, score, mkdir=False):
        if len(score) != self.hashlen:
            raise ValueError("hash %r has bad length" % to_hex(score))
        sz = to_hex(score)
        d = self.path + "/" + sz[:2]
        f = "/" + sz
        if mkdir:
            mkdir_parents(d)
        return d + f

    def put(self, block, kind):
        score = self.hash(block, kind)
        p = self._hash_to_path(score, mkdir=True)
        if not os.path.exists(p):
            print("put %s [%s %s]" % (to_hex(score), kind, len(block)), file=sys.stderr)
            header = self._make_header(kind, len(block))
            with open(p, "wb") as fd:
                fd.write(header)
                fd.write(block)
        return score

    def get(self, score):
        p = self._hash_to_path(score)
        if not os.path.exists(p):
            raise KeyError(to_hex(score))
        with open(p, "rb") as fd:
            header = fd.readline().strip()
            block = fd.read()
        header = header.decode("utf-8")
        kind, size, *rest = header.split(" ")
        if len(block) != int(size):
            raise SizeMismatchError(score, kind, len(block), int(size))
        block_hash = self.hash(block, kind)
        if score != block_hash:
            raise HashMismatchError(score, kind, block_hash)
        return block, kind

    def kind(self, score):
        p = self._hash_to_path(score)
        if not os.path.exists(p):
            raise KeyError(to_hex(score))
        with open(p, "rb") as fd:
            header = fd.readline().strip()
        header = header.decode("utf-8")
        kind, size, *rest = header.split(" ")
        return kind

    def contains(self, score):
        p = self._hash_to_path(score)
        return os.path.exists(p)

    def discard(self, score):
        p = self._hash_to_path(score)
        if os.path.exists(p):
            os.unlink(p)

class LimitedFileBackend(FileBackend):
    blocksize = 64*KiB

# }}}

class KeyValueBackend(Backend): # {{{
    """ Abstract class for a key/value-based backend; i.e. one that does
    not support partial retrievals. It uses separate keys for kind and
    data. """

    def __init__(self):
        raise NotImplementedError

    def _block_key(self, score):
        return "%s.data" % to_hex(score)

    def _kind_key(self, score):
        return "%s.type" % to_hex(score)

    def _make_keys(self, score):
        score_h = to_hex(score)
        return "%s.data" % score_h, "%s.type" % score_h
    
    def get(self, score):
        block, kind = self._get_unverified(score)
        block_hash = self.hash(block, kind)
        if score != block_hash:
            raise HashMismatchError(score, kind, block_hash)
        return block, kind
# }}}

class MemcacheBackend(KeyValueBackend): # {{{
    blocksize = 1000000

    def __init__(self, host="localhost:11211"):
        import memcache
        self.client = memcache.Client([host])

    def put(self, block, kind):
        score = self.hash(block, kind)
        block_key, kind_key = self._make_keys(score)
        if self.client.add(kind_key, kind):
            self.client.add(block_key, block)
            print("put %s [%s %s]" % (to_hex(score), kind, len(block)), file=sys.stderr)
        else:
            pass
            #print("have %s [%s %s]" % (to_hex(score), kind, len(block)), file=sys.stderr)
        return score

    def _get_unverified(self, score):
        block_key, kind_key = self._make_keys(score)
        data = self.client.get_multi([block_key, kind_key])
        if block_key in data and kind_key in data:
            return data[block_key], data[kind_key]
        else:
            raise KeyError(to_hex(score))

    def kind(self, score):
        _, kind_key = self._make_keys(score)
        return self.client.get(kind_key)

    def contains(self, score):
        return self.client.get(self._kind_key(score)) is not None

    def discard(self, score):
        block_key, kind_key = self._make_keys(score)
        self.client.delete_multi([block_key, kind_key])

# }}}

class RedisBackend(KeyValueBackend): # {{{
    blocksize = 512*MiB

    def __init__(self, host="localhost"):
        import redis
        self.client = redis.Redis(host)

    def put(self, block, kind):
        score = self.hash(block, kind)
        block_key, kind_key = self._make_keys(score)
        if self.client.setnx(kind_key, kind):
            self.client.setnx(block_key, block)
        return score

    def _get_unverified(self, score):
        block_key, kind_key = self._make_keys(score)
        kind = self.client.get(kind_key)
        if kind:
            block = self.client.get(block_key)

        if kind and block:
            return block, kind
        else:
            raise KeyError(to_hex(score))

    def kind(self, score):
        _, kind_key = self._make_keys(score)
        return self.client.get(kind_key)

    def contains(self, score):
        return self.client.exists(self._kind_key(score))

    def discard(self, score):
        block_key, kind_key = self._make_keys(score)
        self.client.delete(block_key, kind_key)

# }}}

# vim: fdm=marker

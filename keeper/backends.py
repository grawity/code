import os
import sys
import hashlib

from util import *

class Backend(object):
	""" Abstract class for any storage backend. """

	blocksize = None

	def _make_header(self, type: "str", size: "int") -> "header: bytes[]":
		return ("%s %d\n" % (type, size)).encode("utf-8")

	def hash(self, block: "bytes[]", type: "str") -> "score: bytes[]":
		h = hashlib.sha1()
		h.update(self._make_header(type, len(block)))
		h.update(block)
		return h.digest()

	@property
	def hashlen(self):
		return hashlib.sha1().digest_size

	def put(self, block: "bytes[]", type: "str") -> "score: bytes[]":
		raise NotImplementedError

	def get(self, score: "bytes[]") -> ("block: bytes[]", "type: str"):
		raise NotImplementedError

	def type(self, score: "bytes[]") -> "type: str":
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
		f = "/" + sz[2:]
		if mkdir:
			mkdir_parents(d)
		return d + f

	def put(self, block, type):
		score = self.hash(block, type)
		p = self._hash_to_path(score, mkdir=True)
		if not os.path.exists(p):
			print("put", type, to_hex(score), file=sys.stderr)
			header = self._make_header(type, len(block))
			with open(p, "wb") as fd:
				fd.write(header)
				fd.write(block)
		else:
			print("skip", type, to_hex(score), file=sys.stderr)
			pass
		return score

	def get(self, score):
		p = self._hash_to_path(score)
		if not os.path.exists(p):
			raise KeyError(to_hex(score))
		with open(p, "rb") as fd:
			header = fd.readline().strip()
			block = fd.read()
		header = header.decode("utf-8")
		type, size, *rest = header.split(" ")
		if len(block) != int(size):
			raise SizeMismatchError(score, type, len(block), int(size))
		block_hash = self.hash(block, type)
		if score != block_hash:
			raise HashMismatchError(score, type, block_hash)
		return block, type

	def type(self, score):
		p = self._hash_to_path(score)
		if not os.path.exists(p):
			raise KeyError(to_hex(score))
		with open(p, "rb") as fd:
			header = fd.readline().strip()
		header = header.decode("utf-8")
		type, size, *rest = header.split(" ")
		return type

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
	not support partial retrievals. It uses separate keys for type and
	data. """

	def __init__(self):
		raise NotImplementedError

	def _block_key(self, score):
		return "%s.data" % to_hex(score)

	def _type_key(self, score):
		return "%s.type" % to_hex(score)

	def _make_keys(self, score):
		score_h = to_hex(score)
		return "%s.data" % score_h, "%s.type" % score_h
	
	def get(self, score):
		block, type = self._get(score)
		block_hash = self.hash(block, type)
		if score != block_hash:
			raise HashMismatchError(score, type, block_hash)
		return block, type
# }}}

class MemcacheBackend(KeyValueBackend): # {{{
	blocksize = 1000000

	def __init__(self, host="localhost:11211"):
		import memcache
		self.client = memcache.Client([host])

	def put(self, block, type):
		score = self.hash(block, type)
		block_key, type_key = self._make_keys(score)
		if self.client.add(type_key, type):
			self.client.add(block_key, block)
			print("put %s:%s [%s]" % (type, to_hex(score), len(block)), file=sys.stderr)
		else:
			print("have %s:%s [%s]" % (type, to_hex(score), len(block)), file=sys.stderr)
		return score

	def _get(self, score):
		block_key, type_key = self._make_keys(score)
		data = self.client.get_multi([block_key, type_key])
		if block_key in data and type_key in data:
			return data[block_key], data[type_key]
		else:
			raise KeyError(to_hex(score))

	def type(self, score):
		_, type_key = self._make_keys(score)
		return self.client.get(type_key)

	def contains(self, score):
		return self.client.get(self._type_key(score)) is not None

	def discard(self, score):
		block_key, type_key = self._make_keys(score)
		self.client.delete_multi([block_key, type_key])

# }}}

class RedisBackend(KeyValueBackend): # {{{
	blocksize = 512*MiB

	def __init__(self, host="localhost"):
		import redis
		self.client = redis.Redis(host)

	def put(self, block, type):
		score = self.hash(block, type)
		block_key, type_key = self._make_keys(score)
		if self.client.setnx(type_key, type):
			self.client.setnx(block_key, block)
		return score

	def _get(self, score):
		block_key, type_key = self._make_keys(score)
		type = self.client.get(type_key)
		if type:
			block = self.client.get(block_key)

		if type and block:
			return block, type
		else:
			raise KeyError(to_hex(score))

	def type(self, score):
		_, type_key = self._make_keys(score)
		return self.client.get(type_key)

	def contains(self, score):
		return self.client.exists(self._type_key(score))

	def discard(self, score):
		block_key, type_key = self._make_keys(score)
		self.client.delete(block_key, type_key)

# }}}

# vim: fdm=marker

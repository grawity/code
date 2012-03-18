#!/usr/bin/env python
from __future__ import print_function
import binascii
import hashlib
import os
import pickle
import pprint
import sys

def binhex(buf):
	return binascii.b2a_hex(buf)

def hexbin(buf):
	return binascii.a2b_hex(buf)

class DictStore():
	def __init__(self, path, async=False):
		return NotImplemented
	
	def store(self, key, value):
		return NotImplemented
	
	def retrieve(self, key):
		return NotImplemented
	
	def forget(self, key):
		return NotImplemented
	
	def sync(self):
		return NotImplemented
	
	def __setitem__(self, key, value):
		return self.store(key, value)
	
	def __getitem__(self, key):
		return self.retrieve(key)
	
	def __delitem__(self, key):
		return self.forget(key)
	
	def __del__(self):
		self.sync()

class ShelveDictStore(DictStore):
	def __init__(self, path, async=False):
		self.dbpath = path
		self.async = async
		import shelve
		self.db = shelve.open(path, writeback=async)
		
	def store(self, key, value):
		self.db[key] = value
	
	def retrieve(self, key):
		return self.db[key]
	
	def forget(self, key):
		del self.db[key]
	
	def sync(self):
		self.db.sync()

class JsonDictStore(DictStore):
	import json

	def __init__(self, path, async=False):
		self.dbpath = path
		self.async = async
		self.db = {}
		if os.path.exists(self.dbpath):
			with open(self.dbpath, "r") as fh:
				#self.db = self.json.load(fh)
				self.db = eval(fh.read())
				print("JsonDictStore loaded %d items" % len(self.db))
		
	def store(self, key, value):
		self.db[key] = value
		if not self.async:
			self.sync()
	
	def retrieve(self, key):
		return self.db[key]
	
	def forget(self, key):
		del self.db[key]
	
	def sync(self):
		with open(self.dbpath, "w") as fh:
			#self.json.dump(self.db, fh)
			fh.write(pprint.pformat(self.db))
			print("JsonDictStore saved %d items" % len(self.db))

class BlockStore():
	blocksize = 0

	def hash(self, data):
		return hashlib.sha1(data).digest()

	def store(self, data):
		return NotImplemented

	def retrieve(self, bhash):
		return NotImplemented

	def forget(self, bhash):
		return NotImplemented

class FilesystemBlockStore(BlockStore):
	blocksize = 4096 # arbitrary

	def __init__(self, root):
		self.root = root
		if not os.path.isdir(root):
			os.mkdir(root)
	
	def _objdir(self, bhash):
		bhash = binhex(bhash)
		return os.path.join(self.root, bhash[:2])
		
	def _objpath(self, bhash):
		bhash = binhex(bhash)
		return os.path.join(self.root, bhash[:2], bhash[2:])
		
	def store(self, data):
		bhash = self.hash(data)
		objdir = self._objdir(bhash)
		if not os.path.isdir(objdir):
			os.mkdir(objdir)
		path = self._objpath(bhash)
		if os.path.exists(path):
			# assume filesystem copy is okay
			return bhash
		with open(path, "wb") as fh:
			fh.write(data)
		return bhash
	
	def retrieve(self, bhash):
		path = self._objpath(bhash)
		if os.path.exists(path):
			with open(path, "rb") as fh:
				return fh.read(self.blocksize)
		else:
			raise KeyError

	def forget(self, bhash):
		path = self._objpath(bhash)
		if os.path.exists(path):
			os.unlink(path)
			return True

def store_stream(datast, fh):
	blocks = []
	while True:
		buf = fh.read(datast.blocksize)
		if not buf:
			break
		blocks.append(datast.store(buf))
	return blocks

def retrieve_stream(datast, blocks, fh):
	for bhash in blocks:
		fh.write(datast.retrieve(bhash))
	fh.flush()

def store_file(datast, metast, path):
	meta = {}
	meta["name"] = os.path.basename(path)
	meta["size"] = os.stat(path).st_size
	with open(path, "rb") as fh:
		blocks = store_stream(datast, fh)
	# pickle is very binary-inefficient
	#meta["blocks"] = blocks
	meta["blocks"] = list(map(binhex, blocks))
	metast.store(meta["name"],
		pickle.dumps(meta))
	return meta["name"]

def retrieve_file(datast, metast, path):
	name = os.path.basename(path)
	meta = pickle.loads(metast.retrieve(name))
	pprint.pprint(meta)
	with open(name+".out", "wb") as fh:
		retrieve_stream(datast,
			map(hexbin, meta["blocks"]),
			fh)
	print("retrieved %r" % name)

datast = FilesystemBlockStore("testd")
# for debugability
#metast = ShelveDictStore("testm")
metast = JsonDictStore("testm.json")

for f in sys.argv[1:]:
	store_file(datast, metast, f)
	retrieve_file(datast, metast, f)

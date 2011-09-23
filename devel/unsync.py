#!/usr/bin/env python
import os
import sys
import dbm
import hashlib
import pickle
import struct
from operator import itemgetter
import binascii

blocksize = 2048

def iterdb(dbh):
	k = dbh.firstkey()
	while k is not None:
		yield k
		k = dbh.nextkey(k)

def to_hex(buf):
	return binascii.b2a_hex(buf).decode('utf-8')

def from_hex(buf):
	return binascii.a2b_hex(buf.encode('utf-8'))

def iterstream(fh):
	while True:
		block = fh.read(blocksize)
		if not len(block): return
		yield block

def ByteStorage(path, lazy=False):
	flags = 'c'
	if lazy: flags += 'f'
	return dbm.open(path, flags, 0o600)

class BlockStorage():
	def __init__(self, path):
		self.db = ByteStorage(path, lazy=True)

	def sync(self):
		self.db.sync()
	
	@classmethod
	def bhash(self, block):
		return hashlib.sha1(block).digest()
	
	def put(self, block):
		bhash = self.bhash(block)
		if bhash not in self.db:
			self.db[bhash] = block
		return bhash

	def __contains__(self, bhash):
		return bhash in self.db
	
	def __getitem__(self, bhash):
		return self.db[bhash]
	
	def __delitem__(self, bhash):
		del self.db[bhash]

class SingleBlockStorage():
	def __init__(self, path):
		#self.db = ByteStorage(path, lazy=True)
		self.db = BlockStorage(path)
		self.rc = ByteStorage(path+'-gc', lazy=True)

	def sync(self):
		self.db.sync()
		self.rc.sync()
	
	@classmethod
	def bhash(self, block):
		return self.db.bhash(block)
	
	def put(self, block):
		bhash = self.db.bhash(block)
		if bhash in self.rc:
			refs, = struct.unpack('!Q', self.rc[bhash])
		else:
			refs = 0
			self.db.put(block)
		print("ref", to_hex(bhash), refs+1)
		self.rc[bhash] = struct.pack('!Q', refs+1)
		return bhash
	
	def __contains__(self, bhash):
		return bhash in self.db
	
	def __getitem__(self, bhash):
		return self.db[bhash]
	
	def __delitem__(self, bhash):
		if bhash in self.rc:
			refs, = struct.unpack('!Q', self.rc[bhash])
		else:
			return

		print("unref", to_hex(bhash), refs-1)
		if refs > 1:
			self.rc[bhash] = struct.pack('!Q', refs-1)
		else:
			del self.db[bhash]
			del self.rc[bhash]

class FileStorage():
	def __init__(self, blockstore, metadata):
		self.store = blockstore
		self.meta = metadata

	def exists(self, name):
		assert isinstance(name, bytes), "Must pass bytes()"
		return name in self.meta
	
	def rename(self, name, newname):
		assert isinstance(name, bytes), "Must pass bytes()"
		data = self.meta_get(name)
		data['name'] = newname
		self.meta_put(data)
		self.meta_delete(name)

	def meta_get(self, name):
		assert isinstance(name, bytes), "Must pass bytes()"
		return pickle.loads(self.meta[name])
	
	def meta_put(self, data):
		name = data['name']
		assert isinstance(name, bytes), "Must pass bytes()"
		self.meta[name] = pickle.dumps(data)
	
	def meta_delete(self, name):
		del self.meta[name]
	
	def blob_get(self, name):
		fmeta = self.meta_get(name)
		for bhash in fmeta['blocks']:
			yield self.store[bhash]

	def blob_put(self, name, blocks, btype='file'):
		if self.exists(name):
			oldblocks = self.meta_get(name)['blocks']
		else:
			oldblocks = []

		fmeta = {'name': name,
			'type': btype,
			'size': 0,
			'blocks': []}
		for block in blocks:
			bhash = self.store.put(block)
			fmeta['size'] += len(block)
			fmeta['blocks'].append(bhash)
		self.meta_put(fmeta)
		self.store.sync()

		for bhash in oldblocks:
			del self.store[bhash]
	
	def blob_delete(self, name):
		fmeta = self.meta_get(name)
		for bhash in fmeta['blocks']:
			del self.store[bhash]
		self.meta_delete(name)
		self.store.sync()
	
	def blob_get_stream(self, name, fh):
		for block in self.blob_get(name):
			fh.write(block)

	def blob_put_stream(self, name, fh):
		return self.blob_put(name, iterstream(fh))

	def hash_stream(self, fh):
		return [self.store.bhash(block) for block in iterstream(fh)]

class FileSystem():
	def __init__(self, filestore):
		self.store = filestore
	
	def validate_name(self, name):
		return name.startswith(b'/')
	
	def dir_list(self, name):
		fmeta = self.store.meta_get(name)
		if fmeta['type'] != 'dir':
			raise TypeError("Not a directory: %r" % name)
		return fmeta['files']
	
	def dir_create(self, name):
		if self.store.exists(name):
			raise ValueError("Already exists: %r" % name)
		fmeta = {'name': name,
			'type': 'dir',
			'files': []}
		self.store.meta_put(fmeta)
	
	def dir_delete(self, name):
		self.store.meta_delete(name)
	
	def dir_add_file(self, name, fname):
		fmeta = self.store.meta_get(name)
		if fmeta['type'] != 'dir':
			raise TypeError("Not a directory: %r" % name)
		if fname not in fmeta['files']:
			fmeta['files'].append(fname)
		self.store.meta_put(fmeta)
	
	def dir_del_file(self, name, fname):
		fmeta = self.store.meta_get(name)
		if fmeta['type'] != 'dir':
			raise TypeError("Not a directory: %r" % name)
		if fname in fmeta['files']:
			fmeta['files'].remove(fname)
		self.store.meta_put(fmeta)

store = SingleBlockStorage('/home/grawity/archival-store.db')
meta = ByteStorage('/home/grawity/archival-meta.db')
fstore = FileStorage(store, meta)
fs = FileSystem(fstore)

def file_find_changes(path):
	oldmeta = self.store.meta_get(name)


def storedir(top):
	for root, dirs, files in os.walk(top):
		if ".dropbox.cache" in dirs:
			dirs.remove(".dropbox.cache")
		if ".dropbox" in files:
			files.remove(".dropbox")
		print(root, dirs, files)
		path = (root).encode('utf-8')
		if not fs.store.exists(path):
			fs.dir_create(path)
		for f in files:
			fname = f.encode('utf-8')
			fpath = os.path.join(root, f).encode('utf-8')
			fs.store.blob_put_stream(fpath, open(os.path.join(root, f), 'rb'))
			fs.dir_add_file(path, fname)
		for d in dirs:
			dname = d.encode('utf-8')
			fs.dir_add_file(path, dname)

def unstoredir(top):
	dqueue = [top.encode('utf-8')]
	fqueue = []
	while dqueue:
		path = dqueue.pop(0)

		outd = os.path.join('/tmp', path.decode('utf-8'))
		if not os.path.exists(outd):
			os.mkdir(outd)

		if not fs.store.exists(path):
			return
		files = fs.dir_list(path)
		for f in files:
			fname = path+b'/'+f
			fmeta = fs.store.meta_get(fname)
			if fmeta['type'] == 'dir':
				dqueue.append(fname)
			else:
				outf = os.path.join('/tmp', fname.decode('utf-8'))
				outfh = open(outf, 'wb')
				fs.store.blob_get_stream(fname, outfh)
				outfh.close()

#storedir("Dropbox")
unstoredir("Dropbox")

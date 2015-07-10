#!/usr/bin/env python
import os
import sys
import stat
import hashlib
from collections import defaultdict

# header and hash caches, to avoid reading
# or hashing the same file twice
header_size = 512
file_headers = {}	# path → header
file_hashes = {}	# path → hash

def enum_files(root_dir):
	for subdir, dirs, files in os.walk(root_dir):
		for name in files:
			path = os.path.join(subdir, name)
			yield path

def get_header(path):
	if path not in file_headers:
		print("reading", path, file=sys.stderr)
		with open(path, "rb") as fh:
			file_headers[path] = fh.read(header_size)
	return file_headers[path]

def hash_file(path):
	if path not in file_hashes:
		print("hashing", path, file=sys.stderr)
		h = hashlib.sha1()
		with open(path, "rb") as fh:
			buf = True
			while buf:
				buf = fh.read(4194304)
				h.update(buf)
		file_hashes[path] = h.digest()
	return file_hashes[path]

def find_duplicates(root_dir):
	# dicts keeping duplicate items
	known_sizes = defaultdict(list)		# size → path[]
	known_headers = defaultdict(list)	# (size, header) → path[]
	known_hashes = defaultdict(list)	# (size, hash) → path[]
 
	# find files identical in size
	for path in enum_files(root_dir):
		st = os.lstat(path)
		if not stat.S_ISREG(st.st_mode):
			continue

		known_sizes[st.st_size].append(path)
	
	# find files identical in size and first `header_size` bytes
	for size, paths in known_sizes.items():
		if len(paths) < 2:
			continue

		for path in paths:
			header = get_header(path)
			known_headers[size, header].append(path)

	# find files identical in size and hash
	for (size, header), paths in known_headers.items():
		if len(paths) < 2:
			continue
		if size <= header_size:
			# optimization: don't compare by hash if
			# the entire contents are already known
			yield paths
			continue

		for path in paths:
			filehash = hash_file(path)
			known_hashes[size, filehash].append(path)

	for (size, filehash), paths in known_hashes.items():
		if len(paths) < 2:
			continue
		yield paths

root_dir = sys.argv[1]

for paths in find_duplicates(root_dir):
	print("Duplicates:")
	for path in paths:
		print("    ", path)
	# do something with duplicates here.

print("%d files compared by header" % len(file_headers))
print("%d files compared by hash" % len(file_hashes))

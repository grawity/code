#!/usr/bin/env python
from pprint import pprint
import subprocess

cached = {}
cache_items = []

def cache_put(obj_id, obj_data):
	if len(cache_items) >= 10000:
		del cached[cache_items.pop(0)]
	cached[obj_id] = obj_data
	cache_items.append(obj_id)
	return obj_data

def descend_branch(commitish):
	proc = subprocess.Popen(["git", "rev-list", "--date-order",
				 "--first-parent", commitish],
				stdout=subprocess.PIPE)

	for line in proc.stdout:
		commit_id = line.decode("utf-8").rstrip("\n")
		yield commit_id

def read_tree(treeish, prefix=""):
	cache_id = ("tree", treeish, prefix)
	if cache_id in cached:
		return cached[cache_id]
	files = {}
	proc = subprocess.Popen(["git", "ls-tree", treeish],
				stdout=subprocess.PIPE)
	for line in proc.stdout:
		obj, obj_name = line.decode("utf-8").rstrip("\n").split("\t", 1)
		_, obj_type, obj_id = obj.split(" ")
		files[prefix+"/"+obj_name] = (obj_type, obj_id)
	return cache_put(cache_id, files)

def read_tree_recursive(treeish, prefix=""):
	cache_id = ("rectree", treeish, prefix)
	if cache_id in cached:
		return cached[cache_id]
	files = {}
	tree = read_tree(treeish, prefix)
	for obj_path, (obj_type, obj_id) in tree.items():
		if obj_type == "tree":
			files.update(read_tree_recursive(obj_id, obj_path))
		elif obj_type == "blob":
			files[obj_path] = (obj_type, obj_id)
	return cache_put(cache_id, files)

topmost = {}
last_changes = {}
last_seen_in = {}
last_commit = None
remaining = set()
for i, commit in enumerate(descend_branch("master")):
	tree = read_tree_recursive(commit)
	if i == 0:
		topmost = tree.copy()
		remaining |= topmost.keys()
		last_changes = {path: commit
				for path in tree}
	else:
		found = set()
		for path in remaining:
			if path not in topmost:
				continue
			elif path not in tree:
				last_seen_in[path] = last_commit
			elif tree[path] != topmost[path]:
				last_changes[path] = last_commit
				found.add(path)
		for path in found:
			print("  ", path)
		remaining -= found
	print("descended", last_commit, "-", len(remaining), "files left")
	last_commit = commit
	if not remaining:
		break
for path in remaining:
	if path in last_seen_in:
		print("last seen:", path, last_seen_in[path])
		last_changes[path] = last_seen_in[path]
for path, commit in last_changes.items():
	print(path, commit)

#!/usr/bin/env python
# http://mysql-python.sourceforge.net/MySQLdb.html
#
import os
import sys

class IndexedFileBackend():
	indexes = None

	def __init__(self, path):
		self.path = path
		self.modified = False
		self.data = {key: dict() for key in self.indexes}
		self.load()
	
	def __del__(self):
		self.flush()
	
	def _parse(self, line):
		return NotImplemented
	
	def _unparse(self, entry):
		return NotImplemented

	def load(self):
		for line in open(self.path, 'r'):
			entry = self._parse(line)
			self._insert(entry)
	
	def _insert(self, entry):
		for key in self.data:
			self.data[key][entry[key]] = entry
	
	def dump(self):
		temp = self.path+'.FIXMEFIXMEFIXME'
		fh = open(temp, 'w')
		for entry in self.data:
			line = self._unparse(entry)
			fh.write(line)
		fh.close()
	
	def flush(self):
		if self.modified:
			self.dump()
			self.modified = False
	
	def find(self, key, value):
		if key in self.data:
			return self.data[key][value]
		else:
			raise IndexError("not indexed by %r" % key)
	
	def __iter__(self):
		index = self.indexes[0]
		return iter(self.data[index])
	
	def __getitem__(self, key):
		for index in self.data:
			if key in self.data[index]:
				return self.data[index][key]
		raise KeyError("item %r not found" % key)

class UnixPasswdBackend(IndexedFileBackend):
	def __init__(self, path="/etc/passwd"):
		self.indexes = "name", "uid"
		IndexedFileBackend.__init__(self, path)
	
	def _parse(self, line):
		line = line.strip().split(':', 6)
		name, passwd, uid, gid, gecos, homedir, shell = line
		entry = {
			"name": name,
			"uid": int(uid),
			"gid": int(gid),
			"gecos": gecos,
			"dir": homedir,
			"shell": shell,
			}
		return entry
	
	def _unparse(self, entry):
		line = "%(name)s:x:%(uid)d:%(gid)d:%(gecos)s:%(dir)s:%(shell)s\n" % entry
		return line

class UnixGroupBackend(IndexedFileBackend):
	def __init__(self, path="/etc/group"):
		self.indexes = "name", "gid"
		self._by_member = {}
		IndexedFileBackend.__init__(self, path)
	
	def _parse(self, line):
		line = line.strip().split(':', 3)
		name, passwd, gid, members = line
		entry = {
			"name": name,
			"gid": int(gid),
			"_members": members,
			"members": members.split(",")
			}
		return entry
	
	def _unparse(self, entry):
		entry["_members"] = entry["members"].join(",")
		line = "%(name)s:x:%(gid)d:%(_members)s" % entry
		return line
	
	def _insert(self, entry):
		IndexedFileBackend._insert(self, entry)
		for member in entry["members"]:
			if member not in self._by_member:
				self._by_member[member] = set()
			self._by_member[member].add(entry["name"])
	
	def find_by_member(self, value):
		if value in self._by_member:
			return self._by_member[value]
		else:
			return set()

class YamlBackend():
	pass

class UserDatabase():
	pass

class GroupDatabase():
	def find(self, key, value):
		pass
	
	def find_by_member(self, uname):
		pass

class HesiodDatabase():
	def __init__(self):
		pass

	def add(self, value, primary, *aliases):
		pkey = "%s.%s" % primary
		self.data[pkey] = "TXT", value
		[self.add_alias(primary, alias) for alias in aliases]
	
	def add_alias(self, primary, alias):
		pkey = "%s.%s" % primary
		skey = "%s.%s" % alias
		self.data[skey] = "CNAME", pkey

pwd = UnixPasswdBackend()
grp = UnixGroupBackend()
hesdb = HesiodDatabase()

for name in pwd:
	pwent = pwd[name]
	groups = set()
	groups.add(grp.find("gid", pwent["gid"])["name"])
	groups.update(grp.find_by_member(pwent["name"]))
	pwent["groups"] = groups

	hesdb.add(UnixPasswdBackend._unparse(pwent),
			(pwent["name"], "passwd"),
			(pwent["uid"], "uid"))

for name in grp:
	grent = grp[name]
	hesdb.add(UnixGroupBackend._unparse(grent),
			(grent["name"], "group"),
			(grent["gid"], "gid"))

sys.exit()

def hesiod_unparse_service(entry):
	entry["_aliases"] = " ".join(entry["aliases"])
	return "%(name)s %(proto)s %(port)d %(_aliases)s" % entry

for name in service_db.by_primary_name():
	hesdb.add(hesiod_unparse_service(svent),
			(svent["name"], "service"),
			(svent["port"], "port"),
			*[alias, "service" for alias in svent["aliases"]])

#for entry in user_db:
#	groups = [group_db.find("gid", entry["gid"])]
#	groups += group_db.find_by_member(entry["name"])

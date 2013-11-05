#!/usr/bin/env python
from operator import itemgetter
from collections import defaultdict
import pwd
import grp
from pwd import struct_passwd as PasswdEnt
from grp import struct_group as GroupEnt

class ServEnt(tuple):
	s_name		= property(itemgetter(0))
	s_aliases	= property(itemgetter(1))
	s_port		= property(itemgetter(2))
	s_proto		= property(itemgetter(3))

class GroupDb(list):
	def getgrid(self, gid):
		for item in self:
			if item.gr_gid == gid:
				return item
		raise KeyError()

def txt(domain, text):
	return domain, "TXT", text

def cname(domain, target):
	return domain, "CNAME", target

def generate():
	for item in Db.Passwd:
		domain = "%s.passwd" % item.pw_name
		yield txt(domain, fmt_passwd(item))
		yield cname("%d.passwd" % item.pw_uid, domain)
		yield cname("%d.uid" % item.pw_uid, domain)
		Db.Grplist[item.pw_name].add(item.pw_gid)

	for item in Db.Group:
		domain = "%s.group" % item.gr_name
		yield txt(domain, fmt_group(item))
		yield cname("%d.group" % item.gr_gid, domain)
		yield cname("%d.gid" % item.gr_gid, domain)
		for member in item.gr_mem:
			Db.Grplist[member].add(item.gr_gid)
	
	for member, groups in Db.Grplist.items():
		domain = "%s.grplist" % member
		yield txt(domain, fmt_grplist(groups))

class Db(object):
	Passwd = list()
	Group = GroupDb()
	Grplist = defaultdict(set)

def fmt_passwd(item):
	return "%s:%s:%d:%d:%s:%s:%s" % (
		item.pw_name,
		item.pw_passwd,
		item.pw_uid,
		item.pw_gid,
		item.pw_gecos,
		item.pw_dir,
		item.pw_shell)

def fmt_group(item):
	return "%s:%s:%d:%s" % (
		item.gr_name,
		item.gr_passwd,
		item.gr_gid,
		",".join(item.gr_mem))

def fmt_grplist(item):
	groups = (Db.Group.getgrid(gid) for gid in item)
	return ":".join("%s:%d" % (g.gr_name, g.gr_gid) for g in groups)

Db.Passwd = pwd.getpwall()
Db.Group += grp.getgrall()

for line in generate():
	domain, rrtype, value = line
	if rrtype == "TXT":
		value = '"%s"' % value
	print('%-18s %-6s %s' % (domain, rrtype, value))


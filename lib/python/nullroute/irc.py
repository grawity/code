#!/usr/bin/env python

import re

class InvalidPrefixError(Exception):
	pass

class Prefix(object):
	def __init__(self, nick=None, user=None, host=None):
		self.nick = nick
		self.user = user
		self.host = host

	_re_nuh = re.compile(r'^(.+)!([^!@]+)@([^!@]+)$')

	@classmethod
	def parse(cls, prefix):
		# TODO: I seem to remember having seen prefixes in form !server.tld
		self = cls()
		m = cls._re_nuh.match(prefix)
		if m:
			self.nick, self.user, self.host = m.groups()
		elif "." in prefix:
			self.host = prefix
		else:
			self.nick = prefix
		return self

	def __str__(self):
		if not (self.nick is None or self.user is None or self.host is None):
			return "%s!%s@%s" % (self.nick, self.user, self.host)
		elif self.nick:
			return self.nick
		elif self.host:
			return self.host
		else:
			return "(empty)"

	def __repr__(self):
		return "<IRC.Prefix: %r ! %r @ %r>" % (self.nick, self.user, self.host)

class Line(object):
	def __init__(self, tags=None, prefix=None, cmd=None, args=None):
		self.tags = tags or {}
		self.prefix = prefix
		self.cmd = cmd
		self.args = args or []

	@classmethod
	def split(cls, line):
		line = line.rstrip("\n")
		line = line.split(" ")
		i, n = 0, len(line)
		parv = []
		if i < n and line[i].startswith("@"):
			parv.append(line[i])
			i += 1
			while i < n and line[i] == "":
				i += 1
		if i < n and line[i].startswith(":"):
			parv.append(line[i])
			i += 1
			while i < n and line[i] == "":
				i += 1
		while i < n:
			if line[i].startswith(":"):
				break
			elif line[i] != "":
				parv.append(line[i])
			i += 1
		if i < n:
			trailing = " ".join(line[i:])
			parv.append(trailing[1:])
		return parv

	@classmethod
	def parse(cls, line):
		parv = cls.split(line)
		self = cls()
		if parv and parv[0].startswith("@"):
			tags = parv.pop(0)
			self.tags = {}
			for item in tags[1:].split(";"):
				if "=" in item:
					k, v = item.split("=", 1)
				else:
					k, v = item, True
				self.tags[k] = v

		if parv and parv[0].startswith(":"):
			prefix = parv.pop(0)[1:]
			self.prefix = Prefix.parse(prefix)

		if parv:
			self.cmd = parv.pop(0).upper()
			self.args = parv

		return self
	
	def __repr__(self):
		return "<IRC.Line: tags=%r prefix=%r cmd=%r args=%r>" % (
						self.tags, self.prefix,
						self.cmd, self.args)

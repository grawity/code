#!/usr/bin/env python
from __future__ import (print_function, unicode_literals)
import base64
import socket
import re

class InvalidPrefixError(Exception):
	pass

class Prefix(object):
	def __init__(self, nick=None, user=None, host=None):
		self.nick = nick
		self.user = user
		self.host = host

	_re_nuh = re.compile(br'^(.+)!([^!@]+)@([^!@]+)$')

	@classmethod
	def parse(cls, prefix):
		# TODO: I seem to remember having seen prefixes in form !server.tld
		self = cls()
		m = cls._re_nuh.match(prefix)
		if m:
			self.nick, self.user, self.host = m.groups()
		elif b"." in prefix:
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
		line = line.rstrip(b"\n")
		line = line.split(b" ")
		i, n = 0, len(line)
		parv = []

		if i < n and line[i].startswith(b"@"):
			parv.append(line[i])
			i += 1
			while i < n and line[i] == b"":
				i += 1

		if i < n and line[i].startswith(b":"):
			parv.append(line[i])
			i += 1
			while i < n and line[i] == b"":
				i += 1

		while i < n:
			if line[i].startswith(b":"):
				break
			elif line[i] != b"":
				parv.append(line[i])
			i += 1

		if i < n:
			trailing = b" ".join(line[i:])
			parv.append(trailing[1:])

		return parv

	@classmethod
	def parse(cls, line):
		parv = cls.split(line)
		self = cls()

		if parv and parv[0].startswith(b"@"):
			tags = parv.pop(0)
			self.tags = {}
			for item in tags[1:].split(b";"):
				if b"=" in item:
					k, v = item.split(b"=", 1)
				else:
					k, v = item, True
				self.tags[k] = v

		if parv and parv[0].startswith(b":"):
			prefix = parv.pop(0)[1:]
			self.prefix = Prefix.parse(prefix)

		if parv:
			self.cmd = parv.pop(0).upper()
			self.args = parv

		return self

	@classmethod
	def join(cls, inputv, strict=True):
		parv = [par.encode("utf-8") for par in inputv]

		if b" " in parv[-1] or parv[-1].startswith(b":"):
			last = parv.pop()
		else:
			last = None

		if strict:
			if any(b" " in par for par in parv):
				raise ValueError("Space is only allowed in last parameter")

			i = 2 if parv[0].startswith(b"@") else 1

			if any(par.startswith(b":") for par in parv[i:]):
				raise ValueError("Only first or last parameter may start with ':'")

		if last is not None:
			parv.append(b":" + last)

		return b" ".join(parv)

	def __repr__(self):
		return "<IRC.Line: tags=%r prefix=%r cmd=%r args=%r>" % (
						self.tags, self.prefix,
						self.cmd, self.args)

class Connection(object):
	def __init__(self):
		self.host = None
		self.port = None
		self.ai = None
		self._fd = None
		self._file = None

	def connect(self, host, port, ssl=False):
		self.ai = socket.getaddrinfo(host, str(port), 0, socket.SOCK_STREAM)
		print(repr(self.ai))
		for af, proto, _, cname, addr in self.ai:
			self._fd = socket.socket(af, proto)
			self._fd.connect(addr)
			break
		import io
		self._fi = self._fd.makefile("rwb")

	def writeraw(self, buf):
		self._fi.write(buf+b"\r\n")
		self._fi.flush()

	def readraw(self):
		return self._fi.readline()

	def write(self, *args):
		self.writeraw(Line.join(args))

	def read(self):
		return Line.parse(self.readraw())

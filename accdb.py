#!/usr/bin/env python
from __future__ import print_function
import os
import re
import sys
import uuid

class Database(object):
	def __init__(self):
		self.entries = dict()
		self.order = list()
		self.count = 0
	
	# Import
	
	@classmethod
	def parse(self, *args, **kwargs):
		return self().parseinto(*args, **kwargs)
	
	def parseinto(self, fh):
		data = ""
		lineno = 0
		lastno = 0
		for line in fh:
			lineno += 1
			if line.startswith("="):
				entry = Entry.parse(data, lineno=lastno)
				if entry:
					self.add(entry)
				data = line
				lastno = lineno
			else:
				data += line
		if data:
			entry = Entry.parse(data, lineno=lastno)
			if entry:
				self.add(entry)
		return self
	
	def add(self, entry, lineno=None):
		if entry.itemno is None:
			entry.itemno = self.count + 1
		if entry.lineno is None:
			entry.lineno = lineno
		if entry.uuid is None:
			entry.uuid = uuid.uuid4()

		self.count += 1
		self.entries[entry.uuid] = entry
		self.order.append(entry.uuid)
	
	# Lookup
	
	# FIXME
	#def find_by_name(self, 

	# Aggregate lookup

	def tags(self):
		tags = set()
		for entry in self:
			tags |= entry.tags
		return tags

	# Export
	
	def __iter__(self):
		for uuid in self.order:
			yield self.entries[uuid]

class Entry(object):
	RE_TAGS = re.compile(r'\s*,\s*|\s+')
	RE_KEYVAL = re.compile(r'=|: ')

	def __init__(self):
		self.attributes = dict()
		self.comment = ""
		self.itemno = None
		self.lineno = None
		self.name = None
		self.tags = set()
		self.uuid = None

	# Import

	@classmethod
	def parse(self, *args, **kwargs):
		return self().parseinto(*args, **kwargs)
	
	def parseinto(self, data, lineno=1):
		# lineno is passed here for use in syntax error messages
		self.lineno = lineno

		for line in data.splitlines():
			line = line.lstrip()
			if not line:
				pass
			elif line.startswith("="):
				self.name = line[1:].strip()
			elif line.startswith("+"):
				tags = re.split(self.RE_TAGS, line[1:].strip())
				self.tags.update(tags)
			elif line.startswith(";"):
				self.comment += line[1:] + "\n"
			elif line.startswith("(") and line.endswith(")"):
				# annotations in search output
				pass
			elif line.startswith("{") and line.endswith("}"):
				try:
					self.uuid = uuid.UUID(line)
				except ValueError as e:
					print("Syntax error on %d: %s" % (lineno, e),
						file=sys.stderr)
					self.comment += line + "\n"
			else:
				try:
					key, val = re.split(self.RE_KEYVAL, line, 1)
				except ValueError:
					print("Syntax error on %d: missing value" % lineno,
						file=sys.stderr)
					self.comment += line + "\n"
					continue

				if val.startswith("<private[") and val.endswith("]>"):
					# trying to load a safe dump
					print("Warning on %d: missing private data" % lineno,
						file=sys.stderr)

				if self.is_private_attr(key):
					attr = PrivateAttribute(val)
				else:
					attr = Attribute(val)

				if key in self.attributes:
					self.attributes[key].append(attr)
				else:
					self.attributes[key] = [attr]

			lineno += 1

		return self

	def is_private_attr(self, key):
		return key == "pass" or key.startswith("!")

	# Export

	def attr_names(self):
		# TODO: import attr sort code from accdb v1
		return self.attributes.keys()

	def dump(self, storage=False, reveal=False):
		if storage:
			reveal = True

		data = ""

		if self.lineno and not storage:
			data += "(line %d)\n" % self.lineno

		data += "= %s\n" % (self.name or "(unnamed)")

		for line in self.comment.splitlines():
			data += ";%s\n" % line

		if self.uuid and storage:
			data += "\t{%s}\n" % self.uuid

		for key in self.attr_names():
			for value in self.attributes[key]:
				if reveal:
					value = value.dump()
				data += "\t%s: %s\n" % (key, value)

		if self.tags:
			tags = sorted(self.tags)
			# TODO: fold lines
			data += "\t+ %s\n" % ", ".join(tags)

		return data

	def __str__(self):
		return self.dump(storage=False)
	
	def __bool__(self):
		return bool(self.name or self.attributes or self.tags or self.comment)

class Attribute(str):
	# Nothing special about this class. Exists only for consistency
	# with PrivateAttribute providing a dump() method.

	def __init__(self, value):
		str.__init__(self, value)
	
	def dump(self):
		return str.__str__(self)

class PrivateAttribute(Attribute):
	# Safeguard class to prevent accidential disclosure of private values.
	# Inherits a dump() method from Attribute for obtaining the actual data.

	def __repr__(self):
		return "<private[%d]>" % len(self)

	def __str__(self):
		return "<private[%d]>" % len(self)

db_path = os.environ.get("ACCDB")

db = Database.parse(open(db_path))
for entry in db:
	print(entry.dump(storage=False))

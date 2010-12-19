#!/usr/bin/env python2
# S-exp parser and dumper
#
# Parser code ripped from http://people.csail.mit.edu/rivest/sexp.html
#  (c) 1997 Ronald Rivest

import base64
from StringIO import StringIO

ALPHA      = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
DIGITS     = "0123456789"
WHITESPACE = " \t\v\f\r\n"
PSEUDO_ALPHA = "-./_:*+="
PUNCTUATION = '()[]{}|#"&\\'
VERBATIM = "!%^~;',<>?"

TOKEN_CHARS = DIGITS+ALPHA+PSEUDO_ALPHA

HEX_DIGITS = "0123456789ABCDEFabcdef"
B64_DIGITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef" \
             "ghijklmnopqrstuvwxyz0123456789+/="

escape_names = {
	"\b":	"b",
	"\t":	"t",
	"\v":	"v",
	"\n":	"n",
	"\f":	"f",
	"\r":	"r",
	"\\":	"\\",
}

def load(buf):
	out = list(SexpParser(buf))
	if not out:
		return None
	elif len(out) == 1:
		return out[0]
	else:
		return out

def dump(obj, canonical=False, transport=False):
	if transport:
		canonical = True

	if isinstance(obj, str):
		exp = dumpString(obj, canonical)
	elif isinstance(obj, dict):
		exp = dumpList(obj.items(), canonical)
	elif isinstance(obj, (list, tuple)):
		exp = dumpList(obj, canonical)
	else:
		raise TypeError

	if transport:
		return "{%s}" % base64.b64encode(exp)
	else:
		return exp

def dumpString(obj, canonical=False, hex=False):
	if canonical:
		out = "%d:%s" % (len(obj), obj)
	elif isToken(obj):
		out = str(obj)
	elif isQuoteable(obj):
		out = '"'
		for char in obj:
			if char in escape_names:
				out += "\\"+escape_names[char]
			elif char in "'\"":
				out += "\\"+char
			else:
				out += char
		out += '"'
	elif hex:
		out = "#%s#" % obj.encode("hex")
	else:
		out = "|%s|" % base64.b64encode(obj)

	#return "[%s]%s" % (self.hint.canonical(), out) if self.hint else out
	#return "[%s]%s" % (self.hint, out) if self.hint else out
	return out

def dumpHint(obj, canonical=False):
	return "[%s]" % dumpString(obj, canonical)

def dumpList(obj, canonical=False):
	out = "("
	if canonical:
		out += "".join(dump(x, canonical=True) for x in obj)
	else:
		out += " ".join(dump(x) for x in obj)
	out += ")"
	return out

def toInt(buf):
	num = 0
	for byte in buf:
		num <<= 8
		num |= ord(byte)
	return num

def isToken(string):
	if string[0] in DIGITS:
		return False
	for char in string:
		if char not in TOKEN_CHARS:
			return False
	return True

def isQuoteable(string):
	for char in string:
		if char in VERBATIM:
			return False
		elif 0x20 <= ord(char) < 0x7f:
			pass
		elif char in escape_names:
			pass
		else:
			return False
	return True

class SexpParser(object):
	def __init__(self, buf, encoding="utf-8"):
		self.bytesize = 8
		self.bits = 0
		self.nBits = 0
		self.buf = buf if hasattr(buf, "read") else StringIO(buf)
		self.char = ""
		self.advance()

	def __iter__(self):
		return self

	def next(self):
		obj = self.scanObject()
		if obj:
			return obj
		else:
			raise StopIteration

	@property
	def pos(self):
		return self.buf.tell()

	def advance(self):
		while True:
			self.last = self.char
			self.char = self.buf.read(1)
			if not self.char:
				self.bytesize = 8
				self.char = None
				return self.char

			if self.char is None:
				return self.char
			elif (self.bytesize == 6 and self.char in "|}") \
				or (self.bytesize == 4 and self.char == "#"):
				if self.nBits and (1 << self.nBits)-1 & self.bits:
					raise IOError("%d-bit region ended with %d unused bits at %d" %
						(self.bytesize, self.nBits, self.pos))
				self.bytesize = 8
				return self.char
			elif self.bytesize != 8 and self.char in WHITESPACE:
				# ignore whitespace in hex/base64 regions
				pass
			elif self.bytesize == 6 and self.char == "=":
				self.nBits -= 2
				pass
			elif self.bytesize == 8:
				return self.char
			elif self.bytesize < 8:
				self.bits <<= self.bytesize
				self.nBits += self.bytesize
				if self.bytesize == 6 and self.char in B64_DIGITS:
					self.bits |= B64_DIGITS.index(self.char)
				elif self.bytesize == 4 and self.char in HEX_DIGITS:
					self.bits |= int(self.char, 16)
				else:
					raise IOError("char %r found in %d-bit region" %
						(self.char, self.bytesize))

				if self.nBits >= 8:
					self.nBits -= 8
					self.char = chr((self.bits >> self.nBits) & 0xFF)
					self.bits &= (1 << self.nBits)-1
					return self.char

	def skipWhitespace(self):
		while self.char:
			if self.char in WHITESPACE:
				self.advance()
			elif self.char == ";" and self.last in "\r\n":
				while self.char and self.char not in "\r\n":
					self.advance()
			else:
				return

	def skipChar(self, char):
		if len(char) != 1:
			raise ValueError("only single characters allowed")

		if not self.char:
			raise IOError("EOF found where %r expected" % char)
		elif self.char == char:
			self.advance()
		else:
			raise IOError("char %r found where %r expected" % (
				self.char, char))

	def scanToken(self):
		self.skipWhitespace()
		out = ""
		while self.char and self.char in TOKEN_CHARS:
			out += self.char
			self.advance()
		return out

	def scanDecimal(self):
		i, value = 0, 0
		while self.char and self.char in DIGITS:
			value = value*10 + int(self.char)
			i += 1
			if i > 8:
				raise IOError("decimal %d... too long" % value)
			self.advance()
		return value

	def scanVerbatimString(self, length=None):
		self.skipWhitespace()
		self.skipChar(":")
		if not length:
			raise ValueError("verbatim string had no length")
		out, i = "", 0
		while i < length:
			out += self.char
			self.advance()
			i += 1
		return out

	def scanQuotedString(self, length=None):
		self.skipChar("\"")
		out = ""
		while length is None or len(out) <= length:
			if not self.char:
				raise ValueError("quoted string is missing closing quote")
			elif self.char == "\"":
				if length is None or len(out) == length:
					self.skipChar("\"")
					break
				else:
					raise ValueError("quoted string ended too early (expected %d)" % length)
			elif self.char == "\\":
				c = self.advance()
				if c == "b":			out += "\b"
				elif c == "t":			out += "\t"
				elif c == "v":			out += "\v"
				elif c == "n":			out += "\n"
				elif c == "f":			out += "\f"
				elif c == "r":			out += "\r"
				elif c in "0123":
					s = c + self.advance() + self.advance()
					val = int(s, 8)
					out += chr(val)
				elif c == "x":
					s = self.advance() + self.advance()
					val = int(s, 16)
					out += chr(val)
				elif c == "\n":
					continue
				elif c == "\r":
					continue
				else:
					raise ValueError("unknown escape character \\%s at %d" % (c, self.pos))
			else:
				out += self.char
			self.advance()
		return out

	def scanHexString(self, length=None):
		self.bytesize = 4
		self.skipChar("#")
		out = ""
		while self.char and (self.char != "#" or self.bytesize == 4):
			out += self.char
			self.advance()
		self.skipChar("#")
		if length and length != len(out):
			raise ValueError("hexstring length %d != declared length %d" %
				(len(out), length))
		return out

	def scanBase64String(self, length=None):
		self.bytesize = 6
		self.skipChar("|")
		out = ""
		while self.char and (self.char != "|" or self.bytesize == 6):
			out += self.char
			self.advance()
		self.skipChar("|")
		if length and length != len(out):
			raise ValueError("base64 length %d != declared length %d" %
				(len(out), length))
		return out

	def scanSimpleString(self):
		self.skipWhitespace()
		if not self.char:
			return None
		elif self.char in TOKEN_CHARS and self.char not in DIGITS:
			return self.scanToken()
		elif self.char in DIGITS or self.char in '"#|:':
			if self.char in DIGITS:
				length = self.scanDecimal()
			else:
				length = None
			if self.char == "\"":
				return self.scanQuotedString(length)
			elif self.char == "#":
				return self.scanHexString(length)
			elif self.char == "|":
				return self.scanBase64String(length)
			elif self.char == ":":
				return self.scanVerbatimString(length)
		else:
			raise ValueError("illegal char %r at %d" % (self.char, self.pos))

	def scanString(self):
		hint = None
		if self.char == "[":
			self.skipChar("[")
			hint = self.scanSimpleString()
			self.skipWhitespace()
			self.skipChar("]")
			self.skipWhitespace()
		out = self.scanSimpleString()
		return {"value": out, "hint": hint} if hint else out

	def scanList(self):
		out = []
		self.skipChar("(")
		while True:
			self.skipWhitespace()
			if not self.char:
				raise ValueError("list is missing closing paren")
			elif self.char == ")":
				self.skipChar(")")
				return out
			else:
				out.append(self.scanObject())

	def scanObject(self):
		self.skipWhitespace()
		if not self.char:
			out = None
		elif self.char == "{":
			self.bytesize = 6
			self.skipChar("{")
			out = self.scanObject()
			self.skipChar("}")
		elif self.char == "(":
			out = self.scanList()
		else:
			out = self.scanString()
		return out

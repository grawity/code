#!/usr/bin/env python2
# S-exp parser and dumper
#
# Parser code ripped from http://people.csail.mit.edu/rivest/sexp.html
#  (c) 1997 Ronald Rivest

import base64

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

class String(str):
	hint = None
	
	escape_names = {
		"\b":	"b",
		"\t":	"t",
		"\v":	"v",
		"\n":	"n",
		"\f":	"f",
		"\r":	"r",
		"\\":	"\\",
	}

	def __repr__(self):
		if self.hint:
			return "%s.String(%s, hint=%s)" % (self.__module__,
				str.__repr__(self), str.__repr__(self.hint))
		else:
			return "%s.String(%s)" % (self.__module__, str.__repr__(self))
	
	def __add__(self, other):
		out = str(self) + other
		return self.__class__(out)

	def sexp(self, indent=0, hex=False):
		if self.canBeToken:
			return self.token()
		elif self.canBeQuoted:
			return self.quoted()
		elif hex:
			return self.hex()
		else:
			return self.base64()

	def canonical(self):
		out = "%d:%s" % (len(self), self)
		return "[%s]%s" % (self.hint.canonical(), out) if self.hint else out

	def base64(self, indent=0):
		out = "|%s|" % base64.b64encode(self)
		return "[%s]%s" % (self.hint, out) if self.hint else out
	
	def hex(self, indent=0):
		out = "#%s#" % self.encode("hex")
		return "[%s]%s" % (self.hint, out) if self.hint else out
	
	def token(self):
		out = str(self)
		return "[%s]%s" % (self.hint, out) if self.hint else out
	
	def quoted(self):
		out = '"'
		for char in self:
			if char in String.escape_names:
				out += "\\"+String.escape_names[char]
			elif char in "'\"":
				out += "\\"+char
			else:
				out += char
		out += '"'
		return "[%s]%s" % (self.hint, out) if self.hint else out
	
	@property
	def canBeToken(self):
		for i, char in enumerate(self):
			if i == 0 and char in DIGITS:
				return False
			elif char not in TOKEN_CHARS:
				return False
		return True
	
	@property
	def canBeQuoted(self):
		for char in self:
			if 0x20 <= ord(char) < 0x7f:
				pass
			elif char in String.escape_names:
				pass
			else:
				return False
		return True

class List(list):
	def __repr__(self):
		#return "%s.List(%s)" % (self.__module__, list.__repr__(self))
		return "%s.List(<%d elements>)" % (self.__module__, len(self))

	def sexp(self, indent=0, hex=False):
		indent += 2
		return "(" + ("\n"+" "*indent).join(x.sexp(indent, hex) for x in self) + ")"
	
	def canonical(self):
		return "(" + "".join(x.canonical() for x in self) + ")"
	
	def base64(self):
		return "{%s}" % base64.b64encode(self.canonical())

	def find(self, token, descend=False):
		for i in self:
			if isinstance(i, List):
				if i[0] == token:
					yield i
				elif descend:
					for j in i.find(token, descend):
						yield j

class Sexp(object):
	def __init__(self, string, encoding="utf-8"):
		self.parser = SexpParser(string, encoding)
		self.tree = self.parser.scanObject()

class SexpParser(object):
	def __init__(self, string, encoding="utf-8"):
		#self.buf = string.encode(encoding)
		self.buf = string
		self.pos = 0
		self.char = self.buf[0]

		self.bytesize = 8
		self.bits = 0
		self.nBits = 0

	def advance(self):
		while True:
			try:
				self.pos += 1
				self.char = self.buf[self.pos]
			except IndexError:
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
		while self.char in WHITESPACE:
			self.advance()
	
	def skipChar(self, char):
		if self.char == char:
			self.advance()
		else:
			raise IOError("char %r found where %r expected" % (
				self.char, char))
	
	def scanToken(self):
		self.skipWhitespace()
		out = ""
		while self.char in TOKEN_CHARS:
			out += self.char
			self.advance()
		return String(out)
	
	def scanToEOF(self):
		self.skipWhitespace()
		pos, self.pos = self.pos, len(self)
		return self[pos:]
	
	def scanDecimal(self):
		i, value = 0, 0
		while self.char in DIGITS:
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
			raise IOError("verbatim string had no length")
		out, i = "", 0
		while i < length:
			out += self.char
			self.advance()
			i += 1
		return String(out)
	
	def scanQuotedString(self, length=None):
		self.skipChar("\"")
		out = ""
		while length is None or len(out) <= length:
			if self.char == "\"":
				if length is None or len(out) == length:
					self.skipChar("\"")
					break
				else:
					raise IOError("quoted string ended too early (expected %d)" % length)
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
					raise IOError("unknown escape character \\%s" % c)
			else:
				out += self.char
			self.advance()
		return String(out)
	
	def scanHexString(self, length=None):
		self.bytesize = 4
		self.skipChar("#")
		out = ""
		while self.char and (self.char != "#" or self.bytesize == 4):
			out += self.char
			self.advance()
		self.skipChar("#")
		if length and length != len(out):
			raise IOError("hexstring length %d != declared length %d" %
				(len(out), length))
		return String(out)

	def scanBase64String(self, length=None):
		self.bytesize = 6
		self.skipChar("|")
		out = ""
		while self.char and (self.char != "|" or self.bytesize == 6):
			out += self.char
			self.advance()
		self.skipChar("|")
		if length and length != len(out):
			raise IOError("base64 length %d != declared length %d" %
				(len(out), length))
		return String(out)
	
	def scanSimpleString(self):
		self.skipWhitespace()
		if self.char in TOKEN_CHARS and self.char not in DIGITS:
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
			raise IOError("illegal char %r at pos %d" % (self.char, self.pos))

	def scanString(self):
		hint = None
		if self.char == "[":
			self.skipChar("[")
			hint = self.scanSimpleString()
			self.skipWhitespace()
			self.skipChar("]")
			self.skipWhitespace()
		out = self.scanSimpleString()
		if hint:
			out.hint = hint
		return out
	
	def scanList(self):
		out = List()
		self.skipChar("(")
		while True:
			self.skipWhitespace()
			if self.char == ")":
				self.skipChar(")")
				return out
			else:
				out.append(self.scanObject())
	
	def scanObject(self):
		self.skipWhitespace()
		if self.char == "{":
			self.bytesize = 6
			self.skipChar("{")
			obj = self.scanObject()
			self.skipChar("}")
			return obj
		elif self.char == "(":
			return self.scanList()
		else:
			return self.scanString()

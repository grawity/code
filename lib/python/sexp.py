# S-exp parser and dumper
#
# The simple S-expression format is used by various crypto software, including:
#
#   - 'lsh' SSH server/client, for storing keys
#   - most Off-the-Record IM encryption, for storing OTR keypairs
#   - GnuPG 'gpgsm', for storing private keys (private-keys-v1.d)
#
# Parser code ripped from http://people.csail.mit.edu/rivest/sexp.html
#  (c) 1997 Ronald Rivest

import base64
from StringIO import StringIO

ALPHA		= "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
DIGITS		= "0123456789"
WHITESPACE	= " \t\v\f\r\n"
PSEUDO_ALPHA	= "-./_:*+="
PUNCTUATION	= '()[]{}|#"&\\'
VERBATIM	= "!%^~;',<>?"

TOKEN_CHARS	= DIGITS + ALPHA + PSEUDO_ALPHA

HEX_DIGITS	= "0123456789ABCDEFabcdef"
B64_DIGITS	= "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef" \
			"ghijklmnopqrstuvwxyz0123456789+/="

ESCAPE_CHARS	= {
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
		exp = dump_string(obj, canonical)
	elif isinstance(obj, dict):
		exp = dump_list(obj.items(), canonical)
	elif isinstance(obj, (list, tuple)):
		exp = dump_list(obj, canonical)
	else:
		raise TypeError

	if transport:
		return "{%s}" % base64.b64encode(exp)
	else:
		return exp

def dump_string(obj, canonical=False, hex=False, hint=None):
	if canonical:
		out = "%d:%s" % (len(obj), obj)
	elif is_token(obj):
		out = str(obj)
	elif is_quoteable(obj):
		out = '"'
		for char in obj:
			if char in ESCAPE_CHARS:
				out += "\\"+ESCAPE_CHARS[char]
			elif char in "'\"":
				out += "\\"+char
			else:
				out += char
		out += '"'
	elif hex:
		out = "#%s#" % obj.encode("hex")
	else:
		out = "|%s|" % base64.b64encode(obj)
	
	if hint:
		return "[%s]%s" % (dump_string(hint, canonical, hex, None), out)
	else:
		return out

def dump_hint(obj, canonical=False):
	return "[%s]" % dump_string(obj, canonical)

def dump_list(obj, canonical=False):
	out = "("
	if canonical:
		out += "".join(dump(x, canonical=True) for x in obj)
	else:
		out += " ".join(dump(x) for x in obj)
	out += ")"
	return out

def to_int(buf):
	num = 0
	for byte in buf:
		num <<= 8
		num |= ord(byte)
	return num

def is_token(string):
	if string[0] in DIGITS:
		return False
	for char in string:
		if char not in TOKEN_CHARS:
			return False
	return True

def is_quoteable(string):
	for char in string:
		if char in VERBATIM:
			return False
		elif 0x20 <= ord(char) < 0x7f:
			pass
		elif char in ESCAPE_CHARS:
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
		obj = self.scan_object()
		if obj:
			return obj
		else:
			raise StopIteration

	@property
	def pos(self):
		return self.buf.tell()

	def advance(self):
		"""Get the next byte in the input stream.

		Will read as many input bytes as needed from Base64 or hex areas.
		"""
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
				# Base64 padding
				self.nBits -= 2
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

	def skip_whitespace(self):
		while self.char:
			if self.char in WHITESPACE:
				self.advance()
			elif self.char == ";" and self.last in "\r\n":
				while self.char and self.char not in "\r\n":
					self.advance()
			else:
				return

	def skip_char(self, char):
		"""Skip the next character if it matches expectations."""
		if len(char) != 1:
			raise ValueError("only single characters allowed")

		if not self.char:
			raise IOError("EOF found where %r expected" % char)
		elif self.char == char:
			self.advance()
		else:
			raise IOError("char %r found where %r expected" % (
				self.char, char))

	def scan_token(self):
		self.skip_whitespace()
		out = ""
		while self.char and self.char in TOKEN_CHARS:
			out += self.char
			self.advance()
		return out

	def scan_decimal(self):
		i, value = 0, 0
		while self.char and self.char in DIGITS:
			value = value*10 + int(self.char)
			i += 1
			if i > 8:
				raise IOError("decimal %d... too long" % value)
			self.advance()
		return value

	def scan_verbatim_string(self, length=None):
		"""Return the value of verbatim string with given length."""
		self.skip_whitespace()
		self.skip_char(":")
		if not length:
			raise ValueError("verbatim string had no length")
		out, i = "", 0
		while i < length:
			out += self.char
			self.advance()
			i += 1
		return out

	def scan_quoted_string(self, length=None):
		self.skip_char("\"")
		out = ""
		while length is None or len(out) <= length:
			if not self.char:
				raise ValueError("quoted string is missing closing quote")
			elif self.char == "\"":
				if length is None or len(out) == length:
					self.skip_char("\"")
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

	def scan_hex_string(self, length=None):
		self.bytesize = 4
		self.skip_char("#")
		out = ""
		while self.char and (self.char != "#" or self.bytesize == 4):
			out += self.char
			self.advance()
		self.skip_char("#")
		if length and length != len(out):
			raise ValueError("hexstring length %d != declared length %d" %
				(len(out), length))
		return out

	def scan_base64_string(self, length=None):
		self.bytesize = 6
		self.skip_char("|")
		out = ""
		while self.char and (self.char != "|" or self.bytesize == 6):
			out += self.char
			self.advance()
		self.skip_char("|")
		if length and length != len(out):
			raise ValueError("base64 length %d != declared length %d" %
				(len(out), length))
		return out

	def scan_simple_string(self):
		self.skip_whitespace()
		if not self.char:
			return None
		elif self.char in TOKEN_CHARS and self.char not in DIGITS:
			return self.scan_token()
		elif self.char in DIGITS or self.char in '"#|:':
			if self.char in DIGITS:
				length = self.scan_decimal()
			else:
				length = None
			if self.char == "\"":
				return self.scan_quoted_string(length)
			elif self.char == "#":
				return self.scan_hex_string(length)
			elif self.char == "|":
				return self.scan_base64_string(length)
			elif self.char == ":":
				return self.scan_verbatim_string(length)
			else:
				raise ValueError("illegal char %r at %d" % (self.char, self.pos))
		else:
			raise ValueError("illegal char %r at %d" % (self.char, self.pos))

	def scan_string(self):
		# TODO: How should hints be handled in a Pythonic way?
		hint = None
		if self.char == "[":
			self.skip_char("[")
			hint = self.scan_simple_string()
			self.skip_whitespace()
			self.skip_char("]")
			self.skip_whitespace()
		out = self.scan_simple_string()
		return (hint, out) if hint else out

	def scan_list(self):
		out = []
		self.skip_char("(")
		while True:
			self.skip_whitespace()
			if not self.char:
				raise ValueError("list is missing closing paren")
			elif self.char == ")":
				self.skip_char(")")
				return out
			else:
				out.append(self.scan_object())

	def scan_object(self):
		"""Return the next object of any type."""
		self.skip_whitespace()
		if not self.char:
			out = None
		elif self.char == "{":
			self.bytesize = 6
			self.skip_char("{")
			out = self.scan_object()
			self.skip_char("}")
		elif self.char == "(":
			out = self.scan_list()
		else:
			out = self.scan_string()
		return out

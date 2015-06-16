# S-exp parser and dumper
#
# (c) 2011 Mantas Mikulėnas <grawity@gmail.com>
#
# Based on C source code from <http://people.csail.mit.edu/rivest/sexp.html>
# (c) 1997 Ronald Rivest <rivest@mit.edu>
# Released under MIT Expat License <http://www.gnu.org/licenses/license-list.html#Expat>
#
# The simple S-expression format is used by various crypto software, including:
#
#   - libgcrypt and nettle, for representing various kinds of keys
#   - most Off-the-Record IM encryption implementations, for storing OTR keypairs
#   - 'lsh' SSH server/client, for storing keys
#   - GnuPG 'gpgsm', for storing private keys (private-keys-v1.d)

from __future__ import print_function
import base64
from io import BytesIO

ALPHA           = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
DIGITS          = b"0123456789"
WHITESPACE      = b" \t\v\f\r\n"
PSEUDO_ALPHA    = b"-./_:*+="
PUNCTUATION     = b'()[]{}|#"&\\'
#VERBATIM       = b"!%^~;',<>?"         # Rivest's spec uses these
VERBATIM        = b"!%^~'<>"            # nettle's sexp-conv is more permissive?

TOKEN_CHARS     = DIGITS + ALPHA + PSEUDO_ALPHA

HEX_DIGITS      = b"0123456789ABCDEFabcdef"
B64_DIGITS      = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="

PRINTABLE_CHARS = bytes(range(0x20, 0x80))
ESCAPE_CHARS = {
    b"\b":  b"b",
    b"\t":  b"t",
    b"\v":  b"v",
    b"\n":  b"n",
    b"\f":  b"f",
    b"\r":  b"r",
    b"\\":  b"\\",
}

class SexpParser(object):
    def __init__(self, buf):
        self.bytesize = 8
        self.bits = 0
        self.nBits = 0
        self.buf = buf if hasattr(buf, "read") else BytesIO(buf)
        self.char = b""
        self.advance()

    def __iter__(self):
        return self

    def __next__(self):
        return self.next()

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
            elif (self.bytesize == 6 and self.char in b"|}") \
                or (self.bytesize == 4 and self.char == b"#"):
                if self.nBits and (1 << self.nBits)-1 & self.bits:
                    raise IOError("%d-bit region ended with %d unused bits at %d" %
                        (self.bytesize, self.nBits, self.pos))
                self.bytesize = 8
                return self.char
            elif self.bytesize != 8 and self.char in WHITESPACE:
                # ignore whitespace in hex/base64 regions
                pass
            elif self.bytesize == 6 and self.char == b"=":
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
                    byte = (self.bits >> self.nBits) & 0xFF
                    self.bits &= (1 << self.nBits)-1
                    self.char = bytes([byte])
                    return self.char

    def skip_whitespace(self):
        while self.char:
            if self.char in WHITESPACE:
                self.advance()
            elif self.char == b";" and self.last in b"\r\n":
                while self.char and self.char not in b"\r\n":
                    self.advance()
            else:
                return

    def skip_char(self, char):
        """Skip the next character if it matches expectations."""
        if len(char) != 1:
            raise ValueError("only single characters allowed")
        elif not self.char:
            raise IOError("EOF found where %r expected" % char)
        elif self.char == char:
            self.advance()
        else:
            raise IOError("char %r found where %r expected" % (
                self.char, char))

    def scan_token(self):
        self.skip_whitespace()
        out = b""
        while self.char and self.char in TOKEN_CHARS:
            out += self.char
            self.advance()
        #print("scan_simple_string ->", repr(out))
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
        self.skip_char(b":")
        if not length:
            raise ValueError("verbatim string had no length")
        out, i = b"", 0
        while i < length:
            out += self.char
            self.advance()
            i += 1
        return out

    def scan_quoted_string(self, length=None):
        self.skip_char(b"\"")
        out = b""
        while length is None or len(out) <= length:
            if not self.char:
                raise ValueError("quoted string is missing closing quote")
            elif self.char == b"\"":
                if length is None or len(out) == length:
                    self.skip_char(b"\"")
                    break
                else:
                    raise ValueError("quoted string ended too early (expected %d)" % length)
            elif self.char == b"\\":
                c = self.advance()
                if c in b"\r\n":
                    continue
                elif c in b"0123":
                    s = c + self.advance() + self.advance()
                    val = int(s, 8)
                    out += chr(val)
                elif c == b"b": out += b"\b"
                elif c == b"f": out += b"\f"
                elif c == b"n": out += b"\n"
                elif c == b"r": out += b"\r"
                elif c == b"t": out += b"\t"
                elif c == b"v": out += b"\v"
                elif c == b"x":
                    s = self.advance() + self.advance()
                    val = int(s, 16)
                    out += chr(val)
                else:
                    raise ValueError("unknown escape character \\%s at %d" % (c, self.pos))
            else:
                out += self.char
            self.advance()
        return out

    def scan_hex_string(self, length=None):
        self.bytesize = 4
        self.skip_char(b"#")
        out = b""
        while self.char and (self.char != b"#" or self.bytesize == 4):
            out += self.char
            self.advance()
        self.skip_char(b"#")
        if length and length != len(out):
            raise ValueError("hexstring length %d != declared length %d" %
                (len(out), length))
        return out

    def scan_base64_string(self, length=None):
        self.bytesize = 6
        self.skip_char(b"|")
        out = b""
        while self.char and (self.char != b"|" or self.bytesize == 6):
            out += self.char
            self.advance()
        self.skip_char(b"|")
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
        elif self.char in DIGITS or self.char in b"\"#|:":
            if self.char in DIGITS:
                length = self.scan_decimal()
            else:
                length = None
            if self.char == b"\"":
                return self.scan_quoted_string(length)
            elif self.char == b"#":
                return self.scan_hex_string(length)
            elif self.char == b"|":
                return self.scan_base64_string(length)
            elif self.char == b":":
                return self.scan_verbatim_string(length)
            else:
                raise ValueError("illegal char %r at %d" % (self.char, self.pos))
        else:
            raise ValueError("illegal char %r at %d" % (self.char, self.pos))

    def scan_string(self):
        # TODO: How should hints be handled in a Pythonic way?
        hint = None
        if self.char == b"[":
            self.skip_char(b"[")
            hint = self.scan_simple_string()
            self.skip_whitespace()
            self.skip_char(b"]")
            self.skip_whitespace()
        out = self.scan_simple_string()
        return (hint, out) if hint else out

    def scan_list(self):
        out = []
        self.skip_char(b"(")
        while True:
            self.skip_whitespace()
            if not self.char:
                raise ValueError("list is missing closing paren")
            elif self.char == b")":
                self.skip_char(b")")
                return out
            else:
                out.append(self.scan_object())

    def scan_object(self):
        """Return the next object of any type."""
        self.skip_whitespace()
        if not self.char:
            out = None
        elif self.char == b"{":
            self.bytesize = 6
            self.skip_char(b"{")
            out = self.scan_object()
            self.skip_char(b"}")
        elif self.char == b"(":
            out = self.scan_list()
        else:
            out = self.scan_string()
        return out

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

    if isinstance(obj, (str, bytes)):
        exp = dump_string(obj, canonical)
    elif isinstance(obj, dict):
        exp = dump_list(obj.items(), canonical)
    elif isinstance(obj, (list, tuple)):
        exp = dump_list(obj, canonical)
    elif isinstance(obj, int):
        exp = dump_string(str(obj), canonical)
    else:
        raise TypeError("unsupported object type %r of %r" % (type(obj), obj))

    if transport:
        return b"{" + base64.b64encode(exp) + b"}"
    else:
        return exp

def dump_string(obj, canonical=False, hex=False, hint=None):
    if hasattr(obj, "encode"):
        obj = obj.encode("utf-8")

    if canonical:
        out = ("%d:" % len(obj)).encode("utf-8") + obj
    elif is_token(obj):
        out = bytes(obj)
    elif is_quoteable(obj):
        out = bytearray(b'"')
        # This sucks.
        # In python2, iterates over 1-char strings.
        # In python3, iterates over integers. NOT 1-char bytes()
        # No, screw it. I officially drop Python 2 compatibility here.
        for char in obj:
            if char in ESCAPE_CHARS:
                out += b"\\"
                out += ESCAPE_CHARS[char]
            elif char in b"'\"":
                out += b"\\"
                out.append(char)
            else:
                out.append(char)
        out += b'"'
        out = bytes(out)
    elif hex:
        out = b"#" + obj.encode("hex") + b"#"
    else:
        out = b"|" + base64.b64encode(obj) + b"|"

    # Add [mimetypehint]
    if hint:
        return b"[" + dump_string(hint, canonical, hex, None) + b"]" + out
    else:
        return out

def dump_hint(obj, canonical=False):
    return b"[" + dump_string(obj, canonical) + b"]"

def dump_list(obj, canonical=False):
    out = b"("
    if canonical:
        out += b"".join(dump(x, canonical=True) for x in obj)
    else:
        out += b" ".join(dump(x) for x in obj)
    out += b")"
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
        elif char in PRINTABLE_CHARS:
            pass
        elif char in ESCAPE_CHARS:
            pass
        else:
            return False
    return True

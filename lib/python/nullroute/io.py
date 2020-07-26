import os
import struct
import sys

class BinaryReader():
    def __init__(self, fh):
        self.fh = fh

    def _debug(self, typ, data):
        if os.environ.get("DEBUG"):
            c_on = "\033[33m" if sys.stderr.isatty() else ""
            c_off = "\033[m" if sys.stderr.isatty() else ""
            print(c_on, "#", typ, repr(data), c_off, file=sys.stderr)
        return data

    def seek(self, pos, whence=0):
        return self.fh.seek(pos, whence)

    def read(self, length):
        buf = self.fh.read(length)
        if len(buf) < length:
            if len(buf) == 0:
                raise EOFError("Hit EOF after 0/%d bytes" % length)
            else:
                raise IOError("Hit EOF after %d/%d bytes" % (len(buf), length))
        return self._debug("raw[%d]" % length, buf)

    def _read_fmt(self, length, fmt, typ):
        buf = self.fh.read(length)
        if len(buf) < length:
            if len(buf) == 0:
                raise EOFError("Hit EOF after 0/%d bytes" % length)
            else:
                raise IOError("Hit EOF after %d/%d bytes" % (len(buf), length))
        data, = struct.unpack(fmt, buf)
        return self._debug(typ, data)

    def read_u8(self):
        return self._read_fmt(1, "B", "byte")

    def read_u16_le(self):
        return self._read_fmt(2, "<H", "short")

    def read_u16_be(self):
        return self._read_fmt(2, ">H", "short")

    def read_u24_be(self):
        hi = self._read_fmt(1, "B", "medium.hi")
        lo = self._read_fmt(2, ">H", "medium.lo")
        return (hi << 16) | lo

    def read_u32_le(self):
        return self._read_fmt(4, "<L", "long")

    def read_u32_be(self):
        return self._read_fmt(4, ">L", "long")

    def read_u64_le(self):
        return self._read_fmt(8, "<Q", "quad")

    def read_u64_be(self):
        return self._read_fmt(8, ">Q", "quad")

class SshBinaryReader(BinaryReader):
    def read_bool(self):
        return self._read_fmt(1, "?", "bool")

    def read_byte(self):
        return self.read_u8()

    def read_uint32(self):
        return self.read_u32_be()

    def read_string(self):
        length = self.read_u32_be()
        return self.read(length)

    def read_array(self):
        string = self.read_string()
        return string.split(b",")

    def read_mpint(self):
        buf = self.read_string()
        return int.from_bytes(buf, byteorder="big", signed=False)

class BinaryWriter():
    def __init__(self, fh):
        self.fh = fh

    def _debug(self, typ, data):
        if os.environ.get("DEBUG"):
            c_on = "\033[35m" if sys.stderr.isatty() else ""
            c_off = "\033[m" if sys.stderr.isatty() else ""
            print(c_on, "#", typ, repr(data), c_off, file=sys.stderr)
        return data

    def write(self, buf, flush=False):
        self._debug("raw[%d]" % len(buf), buf)
        ret = self.fh.write(buf)
        if ret and flush:
            self.fh.flush()
        return ret

    def _write_fmt(self, fmt, typ, *args, flush=False):
        buf = struct.pack(fmt, *args)
        self._debug(typ, buf)
        ret = self.fh.write(buf)
        if ret and flush:
            self.fh.flush()
        return ret

    def write_u8(self, val):
        return self._write_fmt("B", "byte", val)

    def write_u16_le(self, val):
        return self._write_fmt("<H", "short", val)

    def write_u16_be(self, val):
        return self._write_fmt(">H", "short", val)

    def write_u24_be(self, x):
        hi = (x >> 16)
        lo = (x & 0xFFFF)
        return self._write_fmt(">BH", "medium", hi, lo)

    def write_u32_le(self, val):
        return self._write_fmt("<L", "long", val)

    def write_u32_be(self, val):
        return self._write_fmt(">L", "long", val)

    def write_u64_le(self, val):
        return self._write_fmt("<Q", "quad", val)

    def write_u64_be(self, val):
        return self._write_fmt(">Q", "quad", val)

class SshBinaryWriter(BinaryWriter):
    def write_bool(self, val):
        return sef._write_fmt("?", "bool", val)

    def write_byte(self, val):
        return self.write_u8(val)

    def write_uint32(self, val):
        return self.write_u32_be(val)

    def write_string(self, buf):
        return self.write_u32_be(len(buf)) and self.write(buf)

    def write_array(self, vec):
        string = b",".join(vec)
        return self.write_string(string)

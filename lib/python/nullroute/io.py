import io
import struct

class StreamWrapper():
    def __init__(self, fh=b""):
        if type(fh) in {bytes, bytearray}:
            self.fh = io.BytesIO(fh)
        elif hasattr(fh, "makefile"):
            self.fh = fh.makefile("rwb")
        else:
            self.fh = fh

    def seek(self, pos, whence=0):
        return self.fh.seek(pos, whence)

    def tell(self):
        return self.fh.tell()

    def read(self, length):
        buf = self.fh.read(length)
        if len(buf) < length:
            if len(buf) == 0:
                raise EOFError("Hit EOF after %d/%d bytes" % (len(buf), length))
            else:
                raise IOError("Hit EOF after %d/%d bytes" % (len(buf), length))
        return buf

    def write(self, buf):
        ret = self.fh.write(buf)
        if ret < len(buf):
            raise IOError("Write truncated at %d/%d bytes" % (ret, len(buf)))
        return ret

    def flush(self):
        return self.fh.flush()

class BinaryReader(StreamWrapper):
    def _read_fmt(self, length, fmt):
        data, = struct.unpack(fmt, self.read(length))
        return data

    def read_u8(self):
        return self._read_fmt(1, "B")

    def read_u16_le(self):
        return self._read_fmt(2, "<H")

    def read_u16_be(self):
        return self._read_fmt(2, ">H")

    def read_u24_be(self):
        hi = self._read_fmt(1, "B")
        lo = self._read_fmt(2, ">H")
        return (hi << 16) | lo

    def read_u32_le(self):
        return self._read_fmt(4, "<L")

    def read_u32_be(self):
        return self._read_fmt(4, ">L")

    def read_u64_le(self):
        return self._read_fmt(8, "<Q")

    def read_u64_be(self):
        return self._read_fmt(8, ">Q")

class BinaryWriter(StreamWrapper):
    def _write_fmt(self, fmt, *args):
        return self.write(struct.pack(fmt, *args))

    def write_u8(self, val):
        return self._write_fmt("B", val)

    def write_u16_le(self, val):
        return self._write_fmt("<H", val)

    def write_u16_be(self, val):
        return self._write_fmt(">H", val)

    def write_u24_be(self, x):
        hi = (x >> 16)
        lo = (x & 0xFFFF)
        return self._write_fmt(">BH", hi, lo)

    def write_u32_le(self, val):
        return self._write_fmt("<L", val)

    def write_u32_be(self, val):
        return self._write_fmt(">L", val)

    def write_u64_le(self, val):
        return self._write_fmt("<Q", val)

    def write_u64_be(self, val):
        return self._write_fmt(">Q", val)

class BinaryStream(BinaryReader, BinaryWriter):
    pass

# SSHv2

class SshPacketReader(BinaryReader):
    def read_bool(self):
        return self._read_fmt(1, "?")

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

class SshPacketWriter(BinaryWriter):
    def write_bool(self, val):
        return self._write_fmt("?", val)

    def write_byte(self, val):
        return self.write_u8(val)

    def write_uint32(self, val):
        return self.write_u32_be(val)

    def write_string(self, buf):
        return self.write_u32_be(len(buf)) and self.write(buf)

    def write_array(self, vec):
        string = b",".join(vec)
        return self.write_string(string)

class SshPacketStream(SshPacketReader, SshPacketWriter, BinaryStream):
    pass

# DNS

class DnsPacketReader(BinaryReader):
    def read_domain(self):
        labels = []
        while True:
            length = self.read_u8()
            if length == 0x00:
                # End of name
                labels.append(b"")
                break
            elif length & 0xC0 == 0x00:
                # Normal label
                buf = self.read(length)
                labels.append(buf)
            elif length & 0xC0 == 0x40:
                # Extended label type (including bit-string labels)
                elt = length & ~0xC0
                raise IOError("extended label types are not supported (type %d)" % elt)
            elif length & 0xC0 == 0xC0:
                # Compressed label
                ptr = (length & ~0xC0) << 8 | self.read_u8()
                pos = self.tell()
                self.seek(ptr)
                labels += self.read_domain()
                self.seek(pos)
                break
            else:
                raise IOError("unknown DNS label type %d" % ((length & 0xC0) >> 6))
        return labels

class DnsPacketWriter(BinaryWriter):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._suffixes = {}

    def write_domain(self, domain):
        labels = domain.encode().lower().strip(b".").split(b".") + [b""]
        ret = 0
        for i, label in enumerate(labels):
            suffix = b".".join(labels[i:]).lower()
            if len(suffix) > 0:
                if suffix in self._suffixes:
                    offset = self._suffixes[suffix]
                    ret += self.write_u16_be(0xC000 | offset)
                    break
                else:
                    self._suffixes[suffix] = self.tell()
            ret += self.write_u8(len(label))
            ret += self.write(label)
        """
        name = dns.name.from_text(domain)
        for i, label in enumerate(name.labels):
            suffix = dns.name.Name(name.labels[i:])
            atroot = len(suffix.labels) == 1
            if not atroot:
                try:
                    offset = self._suffixes[suffix]
                    ret += self.write_u16_be(0xC000 | offset)
                    break
                except KeyError:
                    self._suffixes[suffix] = self.tell()
            ret += self.write_u8(len(label))
            ret += self.write(label)
        """
        return ret

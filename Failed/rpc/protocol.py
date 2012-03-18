import json
import struct

MAGIC = "NullRPC\0"

HEADER = struct.Struct("!8sQ")

def pack_header(length):
	return HEADER.pack(MAGIC, length)

def unpack_header(buf):
	hdr = HEADER.unpack(buf)
	if hdr[0] != MAGIC:
		raise ValueError("Protocol mismatch (bad magic)")
	return hdr[1:]

def recv_pkt(fd):
	buf = fd.read(HEADER.size)
	length = unpack_header(buf)
	buf = fd.read(length)
	return buf

def send_pkt(fd, buf):
	hdr = pack_header(len(buf))
	fd.write(hdr+buf)
	fd.flush()

def recv_obj(fd, decoder=None):
	data = recv_pkt(fd)
	if decoder:
		data = decoder(data)
	obj = json.loads(data.decode("ascii"))
	return obj

def send_obj(fd, obj, encoder=None):
	data = json.dumps(obj, indent=2).encode("ascii")
	if encoder:
		data = encoder(data)
	return send_pkt(fd, data)

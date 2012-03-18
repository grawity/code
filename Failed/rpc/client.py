from __future__ import print_function
from . import protocol
import socket

class Client():
	def __init__(self, fd=None, encoder=None, decoder=None):
		self.fd = fd
		self.encoder = encoder
		self.decoder = decoder
		
	def __getattr__(self, key):
		return ProxyMethod(self, key)
	
	def _send(self, obj):
		protocol.send_obj(self.fd, obj, self.encoder)
	
	def _recv(self):
		return protocol.recv_obj(self.fd, self.decoder)
	
	def _call(self, method, a, kw):
		print("Calling", repr(method), a, kw)
		self._send([method, a, kw])
		return self._recv()

class TcpClient(Client):
	def __init__(self, addr, af=socket.AF_INET):
		self.remote = addr
		self.af = af
		self.socket = socket.socket(af, socket.SOCK_STREAM)
		self.socket.connect(addr)

class ProxyMethod():
	def __init__(self, client, method):
		self.client = client
		self.method = method

	def __call__(self, *a, **kw):
		print("ProxyMethod of", self.method, "called with", a, kw)
		self.client._call(self.method, a, kw)

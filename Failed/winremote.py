from __future__ import print_function
import socket
try:
	import socketserver
except ImportError:
	import SocketServer as socketserver

class WinremoteHandler(socketserver.BaseRequestHandler):
	def handle(self):
		data = self.request.recv(8192)
		print("handling", repr(data))
		self.request.send(data.upper())]

class WinremoteServer(socketserver.TCPServer):
	def __init__(self, af, addr):
		self.address_family = af
		socketserver.TCPServer.__init__(self, addr, WinremoteHandler)

Port = 4096

servers = [
	WinremoteServer(socket.AF_INET6, ("::", Port)),
	WinremoteServer(socket.AF_INET, ("0.0.0.0", Port)),
]

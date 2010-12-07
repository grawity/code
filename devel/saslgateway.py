#!/usr/bin/env python
# SASLproxy v0.2
# (c) <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
from __future__ import print_function
import base64
import socket
import ssl
import select

Config = {
	"listen": {
		# IPv6 localhost is "::1"
		"addr": ("::1", 12345),
		"ipv6": True,
	},
	"connect": {
		"addr": ("chat.freenode.net", 7000),
		"ipv6": True,
		"ssl": True,
	},
	"auth": {
		"user": "",
		"pass": "",
	},
}

def irc_parseline(line):
	line = line.strip()

	if line.startswith(b":"):
		tag, line = line.split(b" ", 1)
		tag = tag[1:]
	else:
		tag = None

	if b" :" in line:
		left, right = line.split(b" :", 1)
		line = left.split(b" ")
		line.append(right)
	else:
		line = line.split(b" ")

	command = line.pop(0).upper()
	return tag, command, line

def sasl_plain():
	authid = Config["auth"]["user"]
	authzid = auth
	passwd = Config["auth"]["pass"]
	data = "%s\0%s\0%s\0" % (authid, authzid, passwd)
	return base64.b64encode(data.encode("utf-8"))

class SASLProxy():
	def __init__(self):
		self.listener = None
		self.client = None
		self.server = None
	
	def listen(self, af, addr):
		self.listener = socket.socket(af, socket.SOCK_STREAM, socket.SOL_TCP)
		self.listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
		self.listener.bind(addr)
		self.listener.listen(1)

	def accept(self):
		self.client, self.client_addr = self.listener.accept()
	
	def connect(self, af, addr):
		self.server = socket.socket(af, socket.SOCK_STREAM, socket.SOL_TCP)
		self.server.connect(addr)

	def start_ssl(self):
		self.server = ssl.wrap_socket(self.server,
			ssl_version=ssl.PROTOCOL_TLSv1)
	
	def proxy(self):
		client = self.client
		server = self.server
		client_buf = b""
		server_buf = b""
		try:
			server.send(b"CAP REQ :sasl\r\n")
			while True:
				r, w, x = [client, server], [], []
				r, w, x = select.select(r, w, x)
				for rfd in r:
					data = rfd.recv(4096)
					if len(data) == 0:
						print("Disconnected.")
						return

					if rfd is client:
						server.send(data)

					elif rfd is server:
						lines = (server_buf+data).splitlines(True)
						if lines[-1].endswith(b"\n"):
							server_buf = b""
						else:
							server_buf = lines.pop()

						for line in lines:
							in_tag, in_cmd, in_args = irc_parseline(line)
							if in_cmd == b"CAP" and in_args[1] == b"ACK":
								caps = in_args[2].split()
								if b"sasl" in caps:
									server.send(b"AUTHENTICATE PLAIN\r\n")
									client.send(b":saslproxy NOTICE * :Performing SASL authentication\r\n")
							elif in_cmd == b"AUTHENTICATE" and in_args[0] == b"+":
								auth = sasl_plain()
								server.send(b"AUTHENTICATE " + auth + b"\r\n")
								continue # don't send to client
							elif in_cmd == b"900" or in_cmd == b"904":
								server.send(b"CAP END\r\n")
							client.send(line)

		except KeyboardInterrupt:
			server.send(b"QUIT :Bye.\r\n")
			client.send(b"ERROR :saslproxy was killed\r\n")
			return

Config["listen"].setdefault("ipv6", socket.has_ipv6)
Config["listen"].setdefault("af",
	socket.AF_INET6 if Config["listen"]["ipv6"] else socket.AF_INET)
Config["connect"].setdefault("ipv6", socket.has_ipv6)
Config["connect"].setdefault("af",
	socket.AF_INET6 if Config["connect"]["ipv6"] else socket.AF_INET)

p = SASLProxy()
print("Waiting on", Config["listen"]["addr"])
p.listen(Config["listen"]["af"], Config["listen"]["addr"])
p.accept()
print("Accepted from", p.client_addr)
p.connect(Config["connect"]["af"], Config["connect"]["addr"])
print("Connected to", Config["connect"]["addr"])
if Config["connect"]["ssl"]:
	p.start_ssl()
p.proxy()

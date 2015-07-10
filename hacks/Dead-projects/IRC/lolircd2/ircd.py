#!/usr/bin/env python3

import os, sys
#import select
from select import *
from socket import *
import nullroute.irc as irc
from fnmatch import fnmatch

class Server(object):
	def __init__(self, sid, name):
		self.sid = sid
		self.name = name
		self.hops = None
		self.conn = None
		self.uplink = None
		self.capab = set()

class User(object):
	def __init__(self, uid, nick):
		self.uid = uid
		self.nick = nick
		self.hops = None
		self.ts = None
		self.umode = None
		self.username = None
		self.hostname = None
		self.ipaddr = None
		self.gecos = None
		self.account = None
		self.meta = dict()
	
	@property
	def sid(self):
		return self.uid[:3]

class Connection(object):
	def __init__(self, ircd, sock):
		self.ircd = ircd
		self.sock = sock
		self.reader = sock.makefile("rb")
		self.writer = sock.makefile("wb", buffering=0)
		self.kind = None
		self.peer = None

	def read(self):
		buf = self.reader.readline()
		if not buf:
			return None
		buf = irc.Line.parse(buf, parse_prefix=False)
		#print("<-- %r" % buf)
		return buf

	def write(self, buf):
		print("--> %s" % buf)
		buf = (buf + "\r\n").encode("utf-8")
		self.writer.write(buf)
	
	def writev(self, *args):
		buf = irc.Line.join(args, encode=False)
		return self.write(buf)
	
	def close(self):
		self.ircd.handle_lost_connection(self)
	
	def ENCAP(self, line):
		target, line.cmd, *line.args = line.args
		if target == "*" or fnmatch(target, self.ircd.name):
			try:
				getattr(self, line.cmd)(line, encap=True)
			except AttributeError:
				print("unknown ENCAP:", line)
	
	def CAPAB(self, line):
		server = self.peer
		for arg in line.args:
			server.capab |= set(arg.split())
	
	def CERTFP(self, line, encap):
		user = self.ircd.clients[line.prefix]
		user.meta["CERTFP"] = line.args[0]
	
	def GCAP(self, line, encap):
		server = self.ircd.servers[line.prefix]
		for arg in line.args:
			server.capab |= set(arg.split())
	
	def LOGIN(self, line, encap):
		user = self.ircd.clients[line.prefix]
		user.meta["LOGIN"] = line.args[0]
	
	def PASS(self, line):
		if not (len(line.args) == 4 and line.args[1] == "TS" and line.args[2] == "6"):
			self.write("ERROR :Bad protocol version")
			self.close()
		sid = line.args[3]
		server = Server(sid, None)
		server.conn = self
		self.peer = server
		self.ircd.servers[sid] = server
	
	def PING(self, line):
		self.writev("PONG", *line.args)
	
	def PONG(self, line):
		pass
	
	def QUIT(self, line):
		del self.ircd.clients[line.prefix]
	
	def SERVER(self, line):
		name, hops, description = line.args
		server = self.peer
		server.name = name
		server.hops = int(hops)
		print("linked to:", "%s[%s]" % (server.name, server.sid))
	
	def SID(self, line):
		name, hops, sid, description = line.args
		server = Server(sid, name)
		server.hops = int(hops)
		server.uplink = line.prefix
		self.ircd.servers[sid] = server
		uplink = self.ircd.servers[server.uplink]
		print("introduced:", "%s[%s]" % (server.name, server.sid),
				"via", "%s[%s]" % (uplink.name, uplink.sid))
	
	def SU(self, line, encap):
		if len(line.args) == 1:
			uid, acct = line.args[0], None
		else:
			uid, acct = line.args
		user = self.ircd.clients[uid]
		user.meta["LOGIN"] = acct
	
	def UID(self, line):
		nick, hops, ts, umode, username, hostname, ipaddr, uid, gecos = line.args
		user = User(uid, nick)
		if user.sid != line.prefix:
			self.write("ERROR :SID mismatch: %r != %r" % (user.sid, line.prefix))
			self.close()
			return
		user.ts = ts
		user.umode = umode
		user.username = username
		user.hostname = hostname
		user.ipaddr = ipaddr
		user.gecos = gecos
		self.ircd.clients[uid] = user
		uplink = self.ircd.servers[user.sid]
		print("introduced:", "%s[%s]" % (user.nick, user.uid),
				"via", "%s[%s]" % (uplink.name, uplink.sid))

class LolIrcd(object):
	def __init__(self, config):
		self.config = config
		self.conns = dict()
		self.epoll = epoll()
		self.servers = {}
		self.clients = {}
		self.sid = "1XY"
		self.name = "ratbox.rain"

	def connect(self):
		for af, addr in self.config["connect"]:
			sock = socket(af, SOCK_STREAM)
			sock.connect(addr)
			conn = Connection(self, sock)
			conn.kind = "server"
			self.conns[sock.fileno()] = conn
			self.epoll.register(sock, EPOLLIN|EPOLLOUT|EPOLLHUP)

	def run(self):
		while True:
			events = self.epoll.poll(timeout=3)
			for fd, event in events:
				conn = self.conns[fd]
				#print("event %d on %r" % (event, conn.sock))
				if event & EPOLLHUP:
					pass
				if event & EPOLLOUT:
					self.handle_connected(conn)
					self.epoll.modify(fd, EPOLLIN|EPOLLHUP)
				if event & EPOLLIN:
					self.handle_received(conn)

	def handle_connected(self, conn):
		conn.write("PASS %s TS 6 :%s" % ("jilles", self.sid))
		conn.write("CAPAB :ENCAP QS")
		conn.write("SERVER %s 0 :%s" % (self.name, "lolz"))

	def handle_received(self, conn):
		data = conn.read()
		if not data:
			self.handle_lost_connection(conn)
		try:
			getattr(conn, data.cmd)(data)
		except AttributeError:
			print("unknown:", data)

	def handle_lost_connection(self, conn):
		print("lost connection:", conn.sock)
		fd = conn.sock.fileno()
		self.epoll.unregister(fd)
		conn.sock.close()
		del self.conns[fd]

class Client(object):
	def __init__(self, ircd):
		self.ircd = ircd

config = {
	"bind": [],
	"connect": [
		#(AF_INET, ("127.0.0.1", 26001)),
		(AF_INET6, ("::1", 26001)),
	],
}

ircd = LolIrcd(config)
ircd.connect()
print("running")
ircd.run()

# vim: ts=4:sw=4

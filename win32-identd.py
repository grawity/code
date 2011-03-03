#!python
from __future__ import print_function
import sys
import ctypes
from ctypes import byref, sizeof
import select
import socket
import struct
import servicemanager
import win32api
import win32con
import win32security
import win32service
import win32serviceutil

NULL		= None
DWORD	= ctypes.c_ulong
UCHAR	= ctypes.c_ubyte
ULONG	= ctypes.c_ulong
WORD	= ctypes.c_ushort

ANY_SIZE	= 1

NO_ERROR	= 0

TCP_CONNECTION_OFFLOAD_STATE 	= DWORD

TCP_TABLE_BASIC_LISTENER			= 0
TCP_TABLE_BASIC_CONNECTIONS			= 1
TCP_TABLE_BASIC_ALL				= 2
TCP_TABLE_OWNER_PID_LISTENER		= 3
TCP_TABLE_OWNER_PID_CONNECTIONS		= 4
TCP_TABLE_OWNER_PID_ALL			= 5
TCP_TABLE_OWNER_MODULE_LISTENER		= 6
TCP_TABLE_OWNER_MODULE_CONNECTIONS	= 7
TCP_TABLE_OWNER_MODULE_ALL		= 8

class MIB_TCPROW_OWNER_PID(ctypes.Structure):
	_fields_ = [
		("dwState",		DWORD),
		("dwLocalAddr",	DWORD),
		("dwLocalPort",	DWORD),
		("dwRemoteAddr",	DWORD),
		("dwRemotePort",	DWORD),
		("dwOwningPid",	DWORD),
	]

class MIB_TCPTABLE_OWNER_PID(ctypes.Structure):
	_fields_ = [
		("dwNumEntries",	DWORD),
		("table",		MIB_TCPROW_OWNER_PID * ANY_SIZE),
	]

class MIB_TCP6ROW_OWNER_PID(ctypes.Structure):
	_fields_ = [
		("dwLocalAddr",	UCHAR * 16),
		("dwLocalScopeId",	DWORD),
		("dwLocalPort",	DWORD),
		("dwRemoteAddr",	UCHAR * 16),
		("dwRemoteScopeId",	DWORD),
		("dwRemotePort",	DWORD),
		("dwState",		DWORD),
		("dwOwningPid",	DWORD),
	]

class MIB_TCP6TABLE_OWNER_PID(ctypes.Structure):
	_fields_ = [
		("dwNumEntries",	DWORD),
		("table",		MIB_TCP6ROW_OWNER_PID * ANY_SIZE),
	]

def get_tcp_table(af):
	_GetExtendedTcpTable = ctypes.windll.iphlpapi.GetExtendedTcpTable
	tableClass = TCP_TABLE_OWNER_PID_CONNECTIONS
	if af == socket.AF_INET:
		_row = MIB_TCPROW_OWNER_PID
	elif af == socket.AF_INET6:
		_row = MIB_TCP6ROW_OWNER_PID

	ANY_SIZE = 65535
	class _table(ctypes.Structure):
		_fields_ = [
			("dwNumEntries",	DWORD),
			("table",		_row * ANY_SIZE),
		]

	dwSize = DWORD(0)
	_GetExtendedTcpTable("", byref(dwSize), False, af, tableClass, 0)
	#print "Expecting %d bytes" % dwSize.value
	table = _table()
	if _GetExtendedTcpTable(byref(table), byref(dwSize), False, af, tableClass, 0) == NO_ERROR:
		for i in range(table.dwNumEntries):
			entry = table.table[i]

			if af == socket.AF_INET:
				local = (entry.dwLocalAddr, entry.dwLocalPort)
				remote = (entry.dwRemoteAddr, entry.dwRemotePort)
			elif af == socket.AF_INET6:
				local = (entry.dwLocalAddr, entry.dwLocalPort, 0, entry.dwLocalScopeId)
				remote = (entry.dwRemoteAddr, entry.dwRemotePort, 0,
					entry.dwRemoteScopeId)

			yield {
				"local": unpack_addr(af, local),
				"remote": unpack_addr(af, remote),
				"pid": entry.dwOwningPid,
			}

def get_connection_pid(af, local_addr, local_port, remote_addr, remote_port):
	for entry in get_tcp_table(af):
		if (entry["local"][0] == local_addr
			and entry["local"][1] == local_port
			and entry["remote"][0] == remote_addr
			and entry["remote"][1] == remote_port):
			return entry["pid"]
	return None

def get_pid_owner(pid):
	proc = win32api.OpenProcess(win32con.PROCESS_QUERY_INFORMATION, False, pid)
	token = win32security.OpenProcessToken(proc, win32con.TOKEN_QUERY)
	user_sid, user_attr = win32security.GetTokenInformation(token, win32security.TokenUser)
	user = win32security.LookupAccountSid(None, user_sid)
	return user[0]

def unpack_addr(af, psockaddr):
	if af == socket.AF_INET:
		addr, port = psockaddr
		addr = socket.inet_ntoa(struct.pack("!L", socket.ntohl(addr)))
		port = socket.ntohs(port)
		return addr, port
	elif af == socket.AF_INET6:
		if len(psockaddr) == 2:
			addr, port = psockaddr
			flow, scope = None, None
		elif len(psockaddr) == 4:
			addr, port, flow, scope = psockaddr
		addr = ":".join("%04x" % x for x in struct.unpack("!8H", addr))
		port = socket.ntohs(port)
		return addr, port, flow, scope

def expand_v6_addr(addr):
	if "::" in addr:
		left, right = addr.split("::", 1)
		left = left.split(":")
		right = right.split(":")
		rest = ['0'] * (8 - len(left) - len(right))
		addr = left+rest+right
	else:
		addr = addr.split(":")
	return ":".join("%04x" % int(c, 16) for c in addr)

def format_addr(host, port):
	return ("[%s]:%s" if ":" in host else "%s:%s") % (host, port)

class Identd():
	def __init__(self, service=None):
		self.listeners = []
		self.clients = []
		self.buffers = {}
		self.requests = {}
		self.port = 113
		self.os_name = "WIN32"
		self._service = service

	def start(self):
		self.listen(socket.AF_INET, "0.0.0.0")
		if socket.has_ipv6:
			self.listen(socket.AF_INET6, "::")
		self.accept()

	def log(self, msg, *args):
		if self._service:
			self._service.log(msg % args)
		else:
			print(msg % args)

	def listen(self, af, addr):
		fd = socket.socket(af, socket.SOCK_STREAM)
		self.log("listening on %s", format_addr(addr, self.port))
		fd.bind((addr, self.port))
		fd.listen(3)
		self.listeners.append(fd)

	def accept(self):
		while True:
			r, w, x = self.listeners[:] + self.clients[:], [], []
			r, w, x = select.select(r, w, x)
			for fd in r:
				if fd in self.listeners:
					self.handle_connection(fd)
				elif fd in self.clients:
					self.handle_in_data(fd)

	def handle_connection(self, fd):
		infd, peer = fd.accept()
		self.log("accepting %s", peer[0])
		self.clients.append(infd)
		self.buffers[infd] = b""

	def handle_in_data(self, fd):
		self.buffers[fd] += fd.recv(1024)
		if b"\n" in self.buffers[fd]:
			try:
				self.handle_req(fd)
			except Exception:
				self.reply(fd, "ERROR", "UNKNOWN-ERROR")

	def handle_req(self, fd):
		try:
			self.requests[fd] = self.buffers[fd].splitlines()[0]
			local_port, remote_port = self.requests[fd].split(",", 1)
			local_port = int(local_port.strip())
			remote_port = int(remote_port.strip())
			self.requests[fd] = "%d,%d" % (local_port, remote_port)
		except ValueError:
			self.reply(fd, "ERROR", "INVALID-PORT")

		local_addr = fd.getsockname()[0]
		remote_addr = fd.getpeername()[0]
		self.log("query %s -> %s",
			format_addr(local_addr, local_port),
			format_addr(remote_addr, remote_port))
		if fd.family == socket.AF_INET6:
			local_addr = expand_v6_addr(local_addr)
			remote_addr = expand_v6_addr(remote_addr)

		pid = get_connection_pid(fd.family, local_addr, local_port, remote_addr, remote_port)
		if pid is not None:
			owner = get_pid_owner(pid)
			if owner:
				owner = owner.replace(":", "_")
				info = "%s,%s:%s" % (self.os_name.encode("utf-8"),
					"UTF-8", owner.encode("utf-8"))
				self.reply(fd, "USERID", info)
			else:
				self.reply(fd, "ERROR", "HIDDEN-USER")
		else:
			self.reply(fd, "ERROR", "NO-USER")

	def reply(self, fd, code, info):
		data = "%s:%s:%s\r\n" % (self.requests[fd], code, info)
		fd.send(data.encode("utf-8"))
		self.close(fd)

	def close(self, fd):
		fd.close()
		self.clients.remove(fd)
		del self.buffers[fd]
		del self.requests[fd]

class IdentdService(win32serviceutil.ServiceFramework):
	_svc_name_ = "identd"
	_svc_display_name_ = "Ident (RFC 1413) responder"

	def __init__(self, args):
		win32serviceutil.ServiceFramework.__init__(self, args)

	def SvcDoRun(self):
		d = Identd(service=self)
		d.start()

	def SvcStop(self):
		self.ReportServiceStatus(win32service.SERVICE_STOPPED)
		sys.exit()

	def log(self, msg, *args):
		servicemanager.LogInfoMsg(msg % args)

if __name__ == "__main__":
	if len(sys.argv) > 1:
		win32serviceutil.HandleCommandLine(IdentdService)
	else:
		d = Identd()
		d.start()

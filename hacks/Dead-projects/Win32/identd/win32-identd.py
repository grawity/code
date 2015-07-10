#!python
from __future__ import print_function

import sys
import ctypes
from ctypes import byref, sizeof
from ctypes.wintypes import BOOL, DWORD
import select
import socket
import struct

try:
    import servicemanager
    import win32api
    import win32con
    import win32security
    import win32service
    import win32serviceutil
except ImportError:
    print("Error: This program requires pywin32.", file=sys.stderr)
    raise

NULL        = None
UCHAR       = ctypes.c_ubyte

ANY_SIZE    = 1

NO_ERROR    = 0

TCP_CONNECTION_OFFLOAD_STATE    = DWORD

TCP_TABLE_BASIC_LISTENER            = 0
TCP_TABLE_BASIC_CONNECTIONS         = 1
TCP_TABLE_BASIC_ALL                 = 2
TCP_TABLE_OWNER_PID_LISTENER        = 3
TCP_TABLE_OWNER_PID_CONNECTIONS     = 4
TCP_TABLE_OWNER_PID_ALL             = 5
TCP_TABLE_OWNER_MODULE_LISTENER     = 6
TCP_TABLE_OWNER_MODULE_CONNECTIONS  = 7
TCP_TABLE_OWNER_MODULE_ALL          = 8

class MIB_TCPROW_OWNER_PID(ctypes.Structure):
    _fields_ = [
        ("dwState",         DWORD),
        ("dwLocalAddr",     DWORD),
        ("dwLocalPort",     DWORD),
        ("dwRemoteAddr",    DWORD),
        ("dwRemotePort",    DWORD),
        ("dwOwningPid",     DWORD),
    ]

class MIB_TCPTABLE_OWNER_PID(ctypes.Structure):
    _fields_ = [
        ("dwNumEntries",    DWORD),
        ("table",           MIB_TCPROW_OWNER_PID * ANY_SIZE),
    ]

class MIB_TCP6ROW_OWNER_PID(ctypes.Structure):
    _fields_ = [
        ("dwLocalAddr",     UCHAR * 16),
        ("dwLocalScopeId",  DWORD),
        ("dwLocalPort",     DWORD),
        ("dwRemoteAddr",    UCHAR * 16),
        ("dwRemoteScopeId", DWORD),
        ("dwRemotePort",    DWORD),
        ("dwState",         DWORD),
        ("dwOwningPid",     DWORD),
    ]

class MIB_TCP6TABLE_OWNER_PID(ctypes.Structure):
    _fields_ = [
        ("dwNumEntries",    DWORD),
        ("table",           MIB_TCP6ROW_OWNER_PID * ANY_SIZE),
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
            ("dwNumEntries",    DWORD),
            ("table",           _row * ANY_SIZE),
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
    return ":".join("%04x" % (int(c, 16) if c != '' else 0) for c in addr)

def format_addr(host, port, *rest):
    return ("[%s]:%s" if ":" in host else "%s:%s") % (host, port)

class Identd():
    def __init__(self, service=None):
        try:
            self.port = socket.getservbyname("auth")
        except socket.error:
            self.port = 113

        self.os_name = "WIN32"
        # Connections waiting for acception, per interface
        self.listen_backlog = 3

        self.listeners = []
        self.clients = []
        self.buffers = {}
        self.peers = {}
        self.requests = {}
        self._service = service

    def start(self):
        """Listen on all IPv4 and IPv6 interfaces and start accepting connections."""

        self.listen(socket.AF_INET, "0.0.0.0")
        if socket.has_ipv6:
            self.listen(socket.AF_INET6, "::")
        self.accept()

    def log(self, level, msg, *args):
        if self._service:
            self._service.log(level, msg % args)
        else:
            print(msg % args)

    def logEx(self, level, msg, *data):
        msg += "\n\n" + "\n".join("%s:\t%s" % item if item else "" for item in data)
        return self.log(level, msg)

    def listen(self, af, addr):
        """Listen on a given address."""

        fd = socket.socket(af, socket.SOCK_STREAM)
        self.log("info", "Listening on %s", format_addr(addr, self.port))
        fd.bind((addr, self.port))
        fd.listen(self.listen_backlog)
        self.listeners.append(fd)

    def accept(self):
        """Wait for incoming data or connections."""
        while True:
            r, w, x = self.listeners + self.clients, [], []
            r, w, x = select.select(r, w, x)
            for fd in r:
                if fd in self.listeners:
                    self.handle_connection(fd)
                elif fd in self.clients:
                    try:
                        self.handle_in_data(fd)
                    except Exception as e:
                        self.log("error", "Error in handle_in_data(): %s: %s",
                            e.__class__.__name__, e)
                        self.close(fd)
                        raise

    def handle_connection(self, fd):
        """Accept incoming connection. Called by accept() for listener sockets on select()"""

        client, peer = fd.accept()
        self.log("info", "Accepting %s (fd=%d)", format_addr(*peer), client.fileno())
        self.clients.append(client)
        self.buffers[client] = b""

    def handle_in_data(self, fd):
        """Accept incoming data. Called by accept() for client sockets on select()"""
        buf = fd.recv(512)
        if not buf:
            self.log("notice", "Lost connection from %s", format_addr(*fd.getpeername()))
            return self.close(fd)
        self.buffers[fd] += buf
        if b"\n" in self.buffers[fd]:
            try:
                self.handle_req(fd)
            except BaseException as e:
                self.log("error", "Error in handle_req(): %s: %s", e.__class__.__name__, e)
                self.reply(fd, "ERROR", "UNKNOWN-ERROR")
                raise
        else:
            # TODO: This assumes that the first packet contains the entire request.
            self.log_invalid_request(fd, self.buffers[fd])

    def handle_req(self, fd):
        local_addr = fd.getsockname()[0]
        remote_addr = fd.getpeername()[0]

        raw_request = self.buffers[fd].splitlines()[0]

        try:
            local_port, remote_port = raw_request.split(b",", 1)
            local_port = int(local_port.strip())
            remote_port = int(remote_port.strip())
        except ValueError:
            return self.log_invalid_request(fd, self.buffers[fd])

        self.requests[fd] = (local_addr, local_port), (remote_addr, remote_port)

        if not (0 < local_port < 65536 and 0 < remote_port < 65536):
            return self.reply(fd, "ERROR", "INVALID-PORT")

        if fd.family == socket.AF_INET6:
            local_addr = expand_v6_addr(local_addr)
            remote_addr = expand_v6_addr(remote_addr)

        pid = get_connection_pid(fd.family,
                                 local_addr, local_port,
                                 remote_addr, remote_port)
        if pid is None:
            return self.reply(fd, "ERROR", "NO-USER")

        owner = self.get_pid_owner(fd, pid)
        if not owner:
            # insufficient privileges?
            return self.reply(fd, "ERROR", "HIDDEN-USER")

        return self.reply_userid(fd, pid, owner)

    def reply(self, fd, code, info):
        """Send a reply to an ident request."""

        try:
            local, remote = self.requests[fd]
        except KeyError:
            local, remote = 0, 0

        self.logEx("notice",
            "Query from %s" % format_addr(*fd.getpeername()),
            ("local",   format_addr(*local)),
            ("remote",  format_addr(*remote)),
            None,
            ("reply",   code),
            ("data",    info),)

        return self.send_reply(fd, local[1], remote[1], code, info)

    def reply_userid(self, fd, pid, owner):
        """Send a success reply and log owner information."""

        try:
            local, remote = self.requests[fd]
        except KeyError:
            local, remote = 0, 0

        sid, username, domain = owner

        username = username.replace(":", "_").replace("\r", "").replace("\n", " ")

        code = "USERID"

        info = "%s,%s:%s" % (self.os_name, "UTF-8", username)

        self.logEx("notice",
            "Successful query from %s." % format_addr(*fd.getpeername()),
            ("local",   format_addr(*local)),
            ("remote",  format_addr(*remote)),
            None,
            ("pid",     pid),
            ("owner",   win32security.ConvertSidToStringSid(sid)),
            ("user",    username),
            ("domain",  domain),
            None,
            ("reply",   code),
            ("info",    info),)

        return self.send_reply(fd, local[1], remote[1], code, info)

    def log_invalid_request(self, fd, raw_req):
        """Send a reply to an unparseable Ident request."""

        self.log("error", "Invalid query from %s\n\n"
            "raw data:\t%r\n"
            "\t(%d bytes)\n",
            format_addr(*fd.getpeername()), raw_req, len(raw_req))

        req = raw_req.rstrip(b"\r\n")

        fd.send(req + ":ERROR:INVALID-PORT\r\n".encode("utf-8"))
        self.close(fd)

    def send_reply(self, fd, lport, rport, code, info):
        """Format and send a raw Ident reply with given parameters."""

        data = "%d,%d:%s:%s\r\n" % (lport, rport, code, info)
        fd.send(data.encode("utf-8"))
        self.close(fd)

    def close(self, fd):
        """Close TCP connection and remove data structures."""

        self.log("debug", "Closing fd %d", fd.fileno())

        try:
            self.clients.remove(fd)
            del self.buffers[fd]
        except (KeyError, ValueError) as e:
            pass

        fd.close()

    # helper functions

    def get_pid_owner(self, fd, pid):
        try:
            proc = win32api.OpenProcess(win32con.PROCESS_QUERY_INFORMATION, False, pid)
            token = win32security.OpenProcessToken(proc, win32con.TOKEN_QUERY)
            user_sid, user_attr = win32security.GetTokenInformation(token,
                        win32security.TokenUser)
            user = win32security.LookupAccountSid(None, user_sid)
            return user_sid, user[0], user[1]
        except win32api.error as e:
            self.logEx("error",
                "%s failed" % funcname,
                ("exception",   e),
                ("function",    e.funcname),
                ("error",       "[%(winerror)d] %(strerror)s" % e),
                None,
                ("process",     pid),)
            raise

class IdentdService(win32serviceutil.ServiceFramework):
    _svc_name_ = "identd"
    _svc_display_name_ = "Ident service"
    _svc_description_ = "Responds to Ident (RFC 1413) requests."
    _svc_deps_ = ["Tcpip", "TermService"]

    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)

    def SvcDoRun(self):
        d = Identd(service=self)
        d.start()

    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOPPED)

    def log(self, level, msg):
        if level == "error":
            servicemanager.LogErrorMsg(msg)
        elif level == "warn":
            servicemanager.LogWarningMsg(msg)
        elif level == "notice":
            servicemanager.LogInfoMsg(msg)
        else:
            pass

if __name__ == "__main__":
    if len(sys.argv) > 1:
        win32serviceutil.HandleCommandLine(IdentdService)
    else:
        d = Identd()
        d.start()

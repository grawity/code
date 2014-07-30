#!python
# a couple of Terminal Services commands

from __future__ import print_function
import sys
import socket
import subprocess
import win32api as Api
import win32ts as Ts
from operator import itemgetter

WTSSessionState = (
    "active",
    "connected",
    "queryconn",
    "shadow",
    "disconnect",
    "idle",
    "listen",
    "reset",
    "down",
    "init",
)

WTSProtocolType = {
    Ts.WTS_PROTOCOL_TYPE_CONSOLE:   "console",
    Ts.WTS_PROTOCOL_TYPE_ICA:       "citrix-ica",
    Ts.WTS_PROTOCOL_TYPE_RDP:       "ms-rdp",
    None:                           "unknown",
}

def IsLocalhost(server):
    return server.lower() == socket.gethostname().lower()

def OpenServer(server=None):
    if (server is None) or IsLocalhost(server):
        server_h = Ts.WTS_CURRENT_SERVER_HANDLE
    else:
        server_h = Ts.WTSOpenServer(server)
    return server_h

def CloseServer(server_h):
    return Ts.WTSCloseServer(server_h)

def EnumServers():
    for name in sorted(Ts.WTSEnumerateServers()):
        yield name.upper(), OpenServer(name)

def EnumSessions():
    for server, server_h in EnumServers():
        for session in EnumServerSessions(server, server_h):
            yield session

def EnumServerSessions(server, server_h):
    for session in Ts.WTSEnumerateSessions(server_h, 1):
        session["Server"] = server
        session["hServer"] = server_h
        try:
            session["User"] = Ts.WTSQuerySessionInformation(session["hServer"],
                session["SessionId"], Ts.WTSUserName)
            session["Protocol"] = Ts.WTSQuerySessionInformation(session["hServer"],
                session["SessionId"], Ts.WTSClientProtocolType)
        except Api.error:
            session["User"] = ""
            session["Protocol"] = None
        yield session

def EnumProcesses():
    for server, server_h in EnumServers():
        for session, pid, image, sid in Ts.WTSEnumerateProcesses(server_h, 1):
            yield {"Server": server, "hServer": server_h,
                "SessionId": session, "Pid": pid, "Image": image, "Sid": sid}

class TermServUtil():
    def cmd_help(self, cmd, args):
        print("Subcommands:")
        print("\tKILL [\\\\server] pid[@server] ...")
        print("\tLOGOUT [\\\\server] sid[@server] ...")
        print("\tLS")
        print("\tPS [\\\\server] [/o:<sort>] [/s:<sid>]")
        print("\t\tsort: n=image name, h=hostname, s=session id")
        print("\tW")
        print("\tWHO")
    def cmd_conn(self, cmd, args):
        target = args[0]
        subprocess.Popen(["mstsc", "/v:%s" % target])

    def cmd_kill(self, cmd, args):
        targets = {}
        def_server = None
        for arg in args:
            arg = arg.upper()
            if arg.startswith("\\\\"):
                def_server = arg[2:]
                continue
            elif "@" in arg:
                pids, server = arg.split("@", 1)
            else:
                pids, server = arg, def_server

            pids = map(int, pids.split(","))
            if server in targets:
                targets[server] += pids
            else:
                targets[server] = pids

        for server in targets:
            server_h = OpenServer(server)
            for pid in targets[server]:
                print("Killing %s on %s" % (pid, server))
                Ts.WTSTerminateProcess(server_h, pid, 1)
            CloseServer(server_h)

    def cmd_logout(self, cmd, args):
        targets = {}
        def_server = None
        for arg in args:
            arg = arg.upper()
            if arg.startswith("\\\\"):
                def_server = arg[2:]
                continue
            elif "@" in arg:
                sids, server = arg.split("@", 1)
            else:
                sids, server = arg, def_server

            sids = map(int, sids.split(","))
            if server in targets:
                targets[server] += sids
            else:
                targets[server] = sids

        for server in targets:
            server_h = OpenServer(server)
            for sid in targets[server]:
                print("Logoff %s on %s" % (sid, server))
                Ts.WTSLogoffSession(server_h, sid, False)
            CloseServer(server_h)

    def cmd_ls(self, cmd, args):
        print(" %-15s %-5s %-5s" % ("HOSTNAME", "USERS", "SESS"))
        print(" "+("-"*78))
        for server, server_h in EnumServers():
            sessions = list(EnumServerSessions(server, server_h))
            nsessions = len(sessions)
            nusers = len(list(filter(itemgetter("User"), sessions)))
            print(" %-15s %-5s %-5s" % (server, nusers, nsessions))

    def cmd_ps(self, cmd, args):
        servers = []
        conditions = []
        sortmode = "nhs"
        for arg in args:
            if arg.startswith("\\\\"):
                servers.append(arg[2:].upper())
            elif arg.startswith("/o:"):
                sortmode = arg[3:]
            elif arg.startswith("/s:"):
                conditions.append((lambda proc, arg: str(proc["SessionId"]) == arg, arg[3:]))
            elif "=" in arg:
                k, v = arg.split("=", 1)
                conditions.append((lambda proc, arg: str(proc[arg[0]]) == arg[1], (k, v)))
        procs = EnumProcesses()
        sessions = EnumSessions()
        byserver = {}
        for session in sessions:
            server = session["Server"]
            if server not in byserver:
                byserver[server] = {}
            byserver[server][session["SessionId"]] = session
        for k in reversed(sortmode):
            if k == "s":
                procs = sorted(procs, key=itemgetter("SessionId"))
            elif k == "h":
                procs = sorted(procs, key=itemgetter("Server"))
            elif k == "n":
                procs = sorted(procs, key=lambda p: p["Image"].lower())
            else:
                print("Unknown sort key '%s'" % k)
                sys.exit()
        for proc in procs:
            proc["User"] = byserver[proc["Server"]][proc["SessionId"]]["User"]
            if len(servers) and proc["Server"] not in servers:
                continue
            if len(conditions) and not all(map(lambda func: func[0](proc, func[1]), conditions)):
                continue
            print(" %(Server)-10s %(User)-14s %(SessionId)5d %(Pid)5d %(Image)s" % proc)

    def cmd_users(self, cmd, args):
        return self.cmd_who("users", args)

    def cmd_w(self, cmd, args):
        return self.cmd_who("users", args)

    def cmd_who(self, cmd, args):
        sessions = EnumSessions()

        if cmd == "who":
            cond = lambda session: True
            sessions = sorted(sessions, key=lambda k: k["SessionId"])
            sessions = sorted(sessions, key=lambda k: k["Server"].lower())
            format = " %(Server)-15s %(WinStationName)-12s %(SessionId)5d %(User)-20s %(State)-6s %(Protocol)-7s"
            print(" %-15s %-12s %5s %-20s %-6s %-7s" % ("SERVERNAME", "SESSIONNAME", "ID", "USERNAME", "STATE", "TYPE"))
        else:
            cond = lambda session: session["User"]
            sessions = sorted(sessions, key=lambda k: k["Server"].lower())
            sessions = sorted(sessions, key=lambda k: k["User"].lower())
            format = " %(User)-20s %(Server)-15s %(WinStationName)-12s %(SessionId)5d %(State)-6s"
            print(" %-20s %-15s %-12s %5s %-6s" % ("USERNAME", "SERVERNAME", "SESSIONNAME", "ID", "STATE"))
        print(" "+("-"*78))
        for session in sessions:
            if not cond(session):
                continue
            session["State"] = WTSSessionState[session["State"]][:6]
            session["Protocol"] = WTSProtocolType[session["Protocol"]]
            if not session["User"]:
                session["User"] = "-"
            print(format % session)

    def unknown(self, cmd, args):
        print("Unknown command '%s'" % cmd, file=sys.stderr)

tsu = TermServUtil()

try:
    command = sys.argv[1].lower()
except IndexError:
    command = "users"
args = sys.argv[2:]

getattr(tsu, "cmd_%s" % command, tsu.unknown)(command, args)

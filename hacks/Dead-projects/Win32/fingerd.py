#!python
# a Finger daemon for Windows NT

import socket as so
import win32api as api
#import win32con as con
import win32ts as ts

def reListSessions(outFh):
    protocols = {
        ts.WTS_PROTOCOL_TYPE_CONSOLE: "console",
        ts.WTS_PROTOCOL_TYPE_ICA: "citrix",
        ts.WTS_PROTOCOL_TYPE_RDP: "rdp",
    }

    #hostname = api.GetComputerName()
    hserver = ts.WTS_CURRENT_SERVER_HANDLE

    currentSessId = ts.WTSGetActiveConsoleSessionId()

    format = "%(user)-16s %(active)1s%(session)-7s %(id)-7s %(protocol)-8s"
    print >> outFh, format % dict(
        user = "USER",
        active = "",
        session = "SESSION",
        id = "ID",
        protocol = "PROTOCOL",
    )

    for session in ts.WTSEnumerateSessions(hserver):
        sessionId = session["SessionId"]
        session["User"] = ts.WTSQuerySessionInformation(hserver, sessionId, ts.WTSUserName)
        #session["Address"] = ts.WTSQuerySessionInformation(hserver, sessionId, ts.WTSClientAddress)
        session["Protocol"] = ts.WTSQuerySessionInformation(hserver, sessionId, ts.WTSClientProtocolType)
        print >> outFh, format % dict(
            user = session["User"] or "(none)",
            session = session["WinStationName"],
            id = "(%d)" % session["SessionId"],
            active = "*" if sessionId == currentSessId else "",
            protocol = protocols[session["Protocol"]],
        )

import sys
reListSessions(sys.stdout)
sys.exit()

def reSingleUser(query):
    pass

def handler(peerSh, addr):
    peerFh = peerSh.makefile()

    query = peerFh.readline().strip("\r\n")
    detailed = False
    if query[:3] == "/W ":
        query = query[3:]
        detailed = True

    reListSessions(peerFh)

    peerFh.close()
    peerSh.close()

opt_force_inet4 = True
port = so.getservbyname("finger") or 79
if so.has_ipv6 and not opt_force_inet4:
    family, interface = so.AF_INET6, "::"
else:
    family, interface = so.AF_INET, "0.0.0.0"

serverSh = so.socket(family, so.SOCK_STREAM)
serverSh.bind((interface, port))
serverSh.listen(1)
print "Listening on %(interface)s/%(port)d" % locals()
while True:
    (peerSh, peerAddr) = serverSh.accept()
    print "Connected from %s:%d" % peerAddr
    handler(peerSh, peerAddr)
serverSh.close()

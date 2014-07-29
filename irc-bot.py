#!/usr/bin/env python3
import base64
import sys
from pprint import pformat

class Frame(object):
    def __init__(self, tags=None, prefix=None, cmd=None, args=None):
        self.tags = tags or {}
        self.prefix = prefix
        self.cmd = cmd
        self.args = args or []

    @classmethod
    def parse(cls, line, parse_prefix=True):
        if hasattr(line, "decode"):
            line = line.decode("utf-8", "replace")
        parv = line.rstrip("\r\n").split(" ")
        i, n = 0, len(parv)
        self = cls()

        while i < n and parv[i] == "":
            i += 1

        if i < n and parv[i].startswith("@"):
            tags = parv[i][1:]
            i += 1
            while i < n and parv[i] == "":
                i += 1

            self.tags = dict()
            for item in tags.split(";"):
                if "=" in item:
                    k, v = item.split("=", 1)
                else:
                    k, v = item, True
                self.tags[k] = v

        if i < n and parv[i].startswith(":"):
            prefix = parv[i][1:]
            i += 1
            while i < n and parv[i] == "":
                i += 1

            if parse_prefix:
                self.prefix = Prefix.parse(prefix)
            else:
                self.prefix = prefix

        if i < n:
            self.cmd = parv[i].upper()

        while i < n:
            if parv[i].startswith(":"):
                trailing = " ".join(parv[i:])
                self.args.append(trailing[1:])
                break
            elif parv[i] != "":
                self.args.append(parv[i])
            i += 1

        return self

    def __repr__(self):
        return "<IRC.Frame: tags=%r prefix=%r cmd=%r args=%r>" \
               % (self.tags, self.prefix, self.cmd, self.args)

class SaslMechanism(object):
    def __init__(self):
        self.stage = 0
        self.inbuf = b""

    def do_step(self, inbuf):
        return None

    def feed(self, inbuf):
        self.inbuf += inbuf
        return None

    def next(self, inbuf=None):
        if inbuf:
            self.inbuf += inbuf
        outbuf = self.do_step(self.inbuf)
        if outbuf is None:
            raise IndexError("no more SASL steps to take")
        self.stage += 1
        self.inbuf = b""
        return outbuf

class SaslEXTERNAL(SaslMechanism):
    name = "EXTERNAL"

    def __init__(self, authzid=None):
        super().__init__()
        self.authz = authzid or ""

    def do_step(self, inbuf):
        if self.stage == 0:
            return self.authz.encode("utf-8")

class SaslPLAIN(SaslMechanism):
    name = "PLAIN"

    def __init__(self, username, password, authzid=None):
        super().__init__()
        self.authz = authzid or username
        self.authn = username
        self.passwd = password

    def do_step(self, inbuf):
        if self.stage == 0:
            buf = "%s\0%s\0%s" % (self.authz, self.authn, self.passwd)
            return buf.encode("utf-8")

def b64chunked(buf):
    buf = base64.b64encode(buf).decode("utf-8")
    size, last = 40, ""
    while buf:
        last = buf[:size]
        yield last or "+"
        buf = buf[size:]
    if not 0 < len(last) < size:
        yield "+"

def trace(*a):
    print(*a, file=sys.stderr)


class IrcClient(object):
    def __init__(self):
        self.settings = {
            "nick": "grawity",
            "pass": "foo",
        }

        self.required_caps = {
            "multi-prefix",
            #"sasl",
        }

        self.wanted_caps = {
            "account-notify",
            "away-notify",
            "extended-join",
            "server-time",
            "znc.in/server-time",
            "znc.in/server-time-iso",
        }

        self.sasl_mech = None
        self.enabled_caps = set()
        self.current_nick = self.settings["nick"]
        self.nick_counter = 0
        self.isupport = {
            "PREFIX":       "(ov)@+",
            "PREFIX.modes": {"o": "@", "v": "+"},
            "PREFIX.chars": {"@": "o", "+": "v"},
            "PREFIX.ranks": {"o": 2, "@": 2,
                             "v": 1, "+": 1},
            "CHANTYPES":    "#",
            "CHANMODES":    "b,k,l,imnpst",
            "CHANMODES.a":  "b",
            "CHANMODES.b":  "k",
            "CHANMODES.c":  "l",
            "CHANMODES.d":  "imnpst",
            "NICKLEN":      9,
            "CASEMAPPING":  "rfc1459",
        }

    def send(self, line):
        line = (line + "\r\n").encode("utf-8")
        trace("\033[35m--> %r\033[m" % line)
        if hasattr(sys.stdout, "detach"):
            sys.stdout = sys.stdout.detach()
        sys.stdout.write(line)
        sys.stdout.flush()

    def recv(self):
        line = sys.stdin.readline()
        if line is None or line == "":
            return None
        frame = Frame.parse(line, parse_prefix=False)
        trace("\033[36m<-- %r\033[m" % frame)
        return frame

    def handshake(self):
        self.send("CAP LS")
        #self.send("PASS %(nick)s:%(pass)s" % self.settings)
        self.send("NICK %(nick)s" % self.settings)
        self.send("USER %(nick)s * * %(nick)s" % self.settings)

    def run(self):
        self.handshake()

        while True:
            frame = self.recv()

            if frame is None:
                break
            elif frame.cmd == "ERROR":
                trace("Server error: \"%s\"" % " ".join(frame.args[1:]))
                break
            elif frame.cmd == "PING":
                send("PONG %s" % " ".join(frame.args[1:]))
            elif frame.cmd == "CAP":
                sub = frame.args[2].upper()
                if sub == "LS":
                    offered_caps = set(frame.args[3].split())
                    trace("Server offers capabilities: %s" % offered_caps)
                    missing_caps = self.required_caps - offered_caps
                    if missing_caps:
                        trace("Server is missing required capabilities: %s" % missing_caps)
                        send("QUIT")
                    request_caps = offered_caps & (self.wanted_caps | self.required_caps)
                    self.send("CAP REQ :%s" % " ".join(request_caps))
                elif sub == "ACK":
                    acked_caps = set(frame.args[3].split())
                    trace("Server enabled capabilities: %s" % acked_caps)
                    self.enabled_caps |= acked_caps
                    if "sasl" in acked_caps:
                        self.sasl_mech = SaslPLAIN(username=self.settings["nick"],
                                                   password=self.settings["pass"])
                        trace("Starting SASL %s authentication" % self.sasl_mech.name)
                        self.send("AUTHENTICATE %s" % self.sasl_mech.name)
                    else:
                        self.send("CAP END")
                elif sub == "NAK":
                    refused_caps = set(frame.args[3].split())
                    trace("Server refused capabilities: %s" % refused_caps)
                    self.send("QUIT")
            elif frame.cmd == "AUTHENTICATE":
                data = frame.args[1]
                if data == "+":
                    outbuf = self.sasl_mech.next()
                elif len(data) == 400:
                    inbuf = b64decode(data)
                    outbuf = self.sasl_mech.feed(inbuf)
                else:
                    outbuf = self.sasl_mech.next(inbuf)
                if outbuf is not None:
                    for chunk in b64chunked(outbuf):
                        self.send("AUTHENTICATE " + chunk)
            elif frame.cmd == "001":
                pass
            elif frame.cmd == "005":
                isupport_tokens = frame.args[2:-1]
                for isupport_item in isupport_tokens:
                    if "=" in isupport_item:
                        k, v = isupport_item.split("=", 1)
                        if k == "CHANMODES":
                            a, b, c, d = v.split(",", 3)
                            self.isupport["CHANMODES.a"] = a
                            self.isupport["CHANMODES.b"] = b
                            self.isupport["CHANMODES.c"] = c
                            self.isupport["CHANMODES.d"] = d
                        elif k in {"CHANLIMIT", "MAXLIST"}:
                            self.isupport["%s.types" % k] = {}
                            limit_tokens = v.split(",")
                            for limit_item in limit_tokens:
                                types, limit = limit_item.split(":", 1)
                                for type in types:
                                    self.isupport["%s.types" % k][type] = int(limit)
                        elif k in {"CHANNELLEN", "NICKLEN", "MODES",
                                   "MONITOR", "TOPICLEN"}:
                            v = int(v)
                        elif k in "EXTBAN":
                            char, types = v.split(",", 1)
                            isupport["EXTBAN.char"] = char
                            isupport["EXTBAN.types"] = types
                        elif k == "NAMESX":
                            if "multi-prefix" not in enabled_caps:
                                send("PROTOCTL NAMESX")
                        elif k == "UHNAMES":
                            if "userhost-in-names" not in enabled_caps:
                                send("PROTOCTL UHNAMES")
                        elif k == "PREFIX":
                            self.isupport["PREFIX.modes"] = {}
                            self.isupport["PREFIX.chars"] = {}
                            modes, chars = v[1:].split(")", 1)
                            num = len(modes)
                            for i in range(num):
                                self.isupport["PREFIX.modes"][modes[i]] = chars[i]
                                self.isupport["PREFIX.chars"][chars[i]] = modes[i]
                                self.isupport["PREFIX.ranks"][modes[i]] = num - i
                                self.isupport["PREFIX.ranks"][chars[i]] = num - i
                    else:
                        k, v = isupport_item, True
                    self.isupport[k] = v
                trace(pformat(self.isupport))
            elif frame.cmd == "433":
                trace("Nickname %r is already in use" % self.settings["nick"])
                nick_counter += 1
                self.current_nick = "%s%d" % (self.settings["nick"], self.nick_counter)
                self.send("NICK " + self.current_nick)
            elif frame.cmd == "903":
                trace("Authentication successful!")
                self.send("CAP END")
            elif frame.cmd == "904":
                if self.sasl_mech.stage == 0:
                    trace("Authentication failed; server does not support SASL %r" %
                          (self.sasl_mech.name))
                else:
                    trace("Authentication failed; the credentials were incorrect")
                self.send("QUIT")
            elif frame.cmd == "908":
                trace("Authentication failed; server does not support SASL %r" %
                      (self.sasl_mech.name))
                self.send("QUIT")
            elif frame.cmd == "PRIVMSG":
                pass # example

client = IrcClient()
client.run()

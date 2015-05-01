#!/usr/bin/env python3
import base64
import sys
from pprint import pformat
from nullroute.irc import Frame

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
    def __init__(self, conn):
        self.conn = conn

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
            "CHANTYPES":    set("#"),
            "CHANMODES":    "b,k,l,imnpst",
            "CHANMODES.a":  set("b"),
            "CHANMODES.b":  set("k"),
            "CHANMODES.c":  set("l"),
            "CHANMODES.d":  set("imnpst"),
            "NICKLEN":      9,
            "CASEMAPPING":  "rfc1459",
        }
        self.low_connected = False
        self.high_connected = False

    def is_channel(self, name):
        return name[0] in self.isupport["CHANTYPES"]

    def strip_prefix(self, name):
        for i, c in enumerate(name):
            if c not in self.isupport["PREFIX.chars"]:
                return name[:i], name[i:]
        raise ValueError("name %r has only prefix characters" % name)

    def send_raw(self, buf):
        trace("\033[35m--> %r\033[m" % buf)
        self.conn.write(buf)
        self.conn.flush()

    def send(self, line):
        buf = (line + "\r\n").encode("utf-8")
        return self.send_raw(buf)

    def sendv(self, *args):
        buf = Frame.join(args)
        return self.send_raw(buf)

    def recv_raw(self):
        buf = self.conn.readline()
        if buf == b"":
            return None
        return buf

    def recv(self):
        buf = self.recv_raw()
        if buf is None:
            return None
        frame = Frame.parse(buf, parse_prefix=False)
        trace("\033[36m<-- %r\033[m" % frame)
        return frame

    def handshake(self):
        self.send("CAP LS")
        #self.send("PASS %(nick)s:%(pass)s" % self.settings)
        self.send("NICK %(nick)s" % self.settings)
        self.send("USER %(nick)s * * %(nick)s" % self.settings)

    def check_low_connected(self):
        if not self.low_connected:
            self.low_connected = True
            yield "connected", {"early": True}

    def check_high_connected(self):
        if not self.high_connected:
            yield from self.check_low_connected()
            self.high_connected = True
            yield "connected", {"early": False}

    def process_frame(self, frame):
        if frame is None:
            yield "disconnected", {"reason": "connection-lost"}
            return False
        elif frame.cmd == "ERROR":
            error = " ".join(frame.args[1:])
            trace("Server error: %r" % error)
            yield "disconnected", {"reason": "server-error", "error": error}
            return False
        elif frame.cmd == "PING":
            self.send("PONG %s" % " ".join(frame.args[1:]))
        elif frame.cmd == "CAP":
            sub = frame.args[2].upper()
            if sub == "LS":
                offered_caps = set(frame.args[3].split())
                trace("Server offers capabilities: %s" % offered_caps)
                missing_caps = self.required_caps - offered_caps
                if missing_caps:
                    trace("Server is missing required capabilities: %s" % missing_caps)
                    self.send("QUIT")
                    yield "disconnected", {
                        "reason":   "missing-caps",
                        "caps":     missing_caps,
                        "refused":  False,
                    }
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
                yield "disconnected", {
                    "reason":   "missing-caps",
                    "caps":     refused_caps,
                    "refused":  True,
                }
        elif frame.cmd == "AUTHENTICATE":
            data = frame.args[1]
            if data == "+":
                outbuf = self.sasl_mech.next()
            elif len(data) == 400:
                inbuf = b64decode(data)
                outbuf = self.sasl_mech.feed(inbuf)
            else:
                outbuf = self.sasl_mech.next(inbuf)
            if outbuf is None:
                trace("SASL mechanism did not return any data")
                self.send("QUIT")
                yield "disconnected", {"reason": "auth-failed"}
            for chunk in b64chunked(outbuf):
                self.send("AUTHENTICATE " + chunk)
        elif frame.cmd == "001":
            yield from self.check_low_connected()
        elif frame.cmd == "005":
            isupport_tokens = frame.args[2:-1]
            for isupport_item in isupport_tokens:
                if "=" in isupport_item:
                    k, v = isupport_item.split("=", 1)
                    if k == "CHANMODES":
                        a, b, c, d = v.split(",", 3)
                        self.isupport["CHANMODES.a"] = set(a)
                        self.isupport["CHANMODES.b"] = set(b)
                        self.isupport["CHANMODES.c"] = set(c)
                        self.isupport["CHANMODES.d"] = set(d)
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
                    elif k == "CHANTYPES":
                        v = set(v)
                    elif k == "EXTBAN":
                        char, types = v.split(",", 1)
                        self.isupport["EXTBAN.char"] = char
                        self.isupport["EXTBAN.types"] = set(types)
                    elif k == "NAMESX":
                        if "multi-prefix" not in enabled_caps:
                            self.send("PROTOCTL NAMESX")
                    elif k == "UHNAMES":
                        if "userhost-in-names" not in enabled_caps:
                            self.send("PROTOCTL UHNAMES")
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
        elif frame.cmd == "XXX END OF MOTD":
            yield from self.check_high_connected()
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
            yield "disconnected", {"reason": "auth-failed"}
        elif frame.cmd == "908":
            trace("Authentication failed; server does not support SASL %r" %
                  (self.sasl_mech.name))
            self.send("QUIT")
            yield "disconnected", {"reason": "auth-failed"}
        elif frame.cmd == "PRIVMSG":
            if len(frame.args) != 3:
                return True
            _, rcpt, text = frame.args
            yield "message", {
                "from":     frame.prefix,
                "to":       rcpt,
                "text":     text,
                "private":  not self.is_channel(rcpt),
            }
        elif frame.cmd == "NOTICE":
            if len(frame.args) != 3:
                return True
            _, rcpt, text = frame.args
            yield "notice", {
                "from":     frame.prefix,
                "to":       rcpt,
                "text":     text,
                "private":  not self.is_channel(rcpt),
            }
        return True

    def process(self, buf):
        frame = Frame.parse(buf, parse_prefix=False)
        trace("\033[36m<-- %r\033[m" % frame)
        return self.process_frame(frame)

    def run(self):
        self.handshake()
        while True:
            frame = self.recv()
            if frame is None:
                break

            ok = yield from self.process_frame(frame)
            if ok == False:
                break

    def send_message(self, rcpt, text):
        self.sendv("PRIVMSG", rcpt, text)

class PipeWrapper(object):
    def __init__(self, rd, wr):
        self.rd = rd
        self.wr = wr

    @classmethod
    def from_stdio(klass):
        if hasattr(sys.stdin, "detach"):
            sys.stdin = sys.stdin.detach()
        if hasattr(sys.stdout, "detach"):
            sys.stdout = sys.stdout.detach()
        return klass(sys.stdin, sys.stdout)

    def read(self, size):
        return self.rd.read(size)

    def readline(self):
        return self.rd.readline()

    def write(self, buf):
        return self.wr.write(buf)

    def flush(self):
        return self.wr.flush()

conn = PipeWrapper.from_stdio()
client = IrcClient(conn)
for event, data in client.run():
    trace("%s:" % event, pformat(data))

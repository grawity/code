import base64, sys

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

class Sasl(object):
    def __init__(self):
        self.stage = 0
        self.inbuf = b""

    def do_step(self, inbuf):
        return b""

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

class SaslPLAIN(Sasl):
    name = "PLAIN"

    def __init__(self, username, password):
        super().__init__()
        self.authz = username
        self.authn = username
        self.passwd = password

    def do_step(self, inbuf):
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

def send(line):
    line = (line + "\r\n").encode("utf-8")
    print("sending: %r" % line, file=sys.stderr)
    if hasattr(sys.stdout, "detach"):
        sys.stdout = sys.stdout.detach()
    sys.stdout.write(line)
    sys.stdout.flush()

def recv():
    line = sys.stdin.readline()
    frame = Frame.parse(line, parse_prefix=False)
    print("received: %r" % frame, file=sys.stderr)
    return frame

settings = {"nick": "grawity", "pass": "foo"}

required_caps = {"sasl"}
wanted_caps = {"multi-prefix"}

sasl_mech = None
enabled_caps = set()

send("CAP LS")
send("PASS %(nick)s:%(pass)s" % settings)
send("NICK %(nick)s" % settings)
send("USER %(nick)s * * %(nick)s" % settings)

while True:
    frame = recv()

    if frame.cmd == "PING":
        send("PONG %s" % " ".join(frame.args))
    elif frame.cmd == "CAP":
        sub = frame.args[1].upper()
        if sub == "LS":
            print("Server offers capabilities: %s" % frame.args[2])
            offered_caps = set(frame.args[2].split())
            missing_caps = required_caps - offered_caps
            if missing_caps:
                print("Server is missing required capabilities: %s" % missing_caps)
                send("QUIT")
            request_caps = offered_caps & (wanted_caps | required_caps)
            send("CAP REQ :%s" % " ".join(request_caps))
        elif sub == "ACK":
            acked_caps = set(frame.args[2].split())
            enabled_caps |= acked_caps
            if "sasl" in acked_caps:
                sasl_mech = SaslPLAIN(username=settings["nick"],
                                       password=settings["pass"])
                send("AUTHENTICATE %s" % sasl_mech.name)
        elif sub == "NAK":
            print("Server refused capabilities: %s" % frame.args[2])
            send("QUIT")
    elif frame.cmd == "AUTHENTICATE":
        data = frame.args[1]
        if data == "+":
            outbuf = sasl_mech.next()
        elif len(data) == 400:
            inbuf = b64decode(data)
            outbuf = sasl_mech.feed(inbuf)
        else:
            outbuf = sasl_mech.next(inbuf)
        if outbuf is not None:
            for chunk in b64chunked(outbuf):
                send("AUTHENTICATE " + chunk)
    elif frame.cmd == "903":
        print("Authentication successful!")
        send("CAP END")
    elif frame.cmd == "904":
        if sasl_mech.stage == 0:
            print("Authentication failed because server does not support SASL PLAIN")
        else:
            print("Authentication failed because the credentials were incorrect")
        send("QUIT")
    elif frame.cmd == "908":
        print("Authentication failed because server does not support SASL PLAIN")
        send("QUIT")
    elif frame.cmd == "PRIVMSG":
        pass # example

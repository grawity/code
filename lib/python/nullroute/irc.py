# Parser for IRC protocol messages (RFC 1459 + IRCv3 message-tag extension)
#
# (c) Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

from __future__ import (print_function, unicode_literals)
import base64
import socket
import re

class InvalidPrefixError(Exception):
    pass

class Prefix(object):
    def __init__(self, nick=None, user=None, host=None, is_server=False):
        self.nick = nick
        self.user = user
        self.host = host
        self.is_server = is_server

    @classmethod
    def parse(cls, prefix):
        if len(prefix) == 0:
            return None

        dpos = prefix.find(".") + 1
        upos = prefix.find("!") + 1
        hpos = prefix.find("@", upos) + 1

        if upos == 1 or hpos == 1:
            return None
        if 0 < dpos < min(upos, hpos):
            return None

        self = cls()
        if upos > 0:
            self.nick = prefix[:upos-1]
            if hpos > 0:
                self.user = prefix[upos:hpos-1]
                self.host = prefix[hpos:]
            else:
                self.user = prefix[upos:]
        elif hpos > 0:
            self.nick = prefix[:hpos-1]
            self.host = prefix[hpos:]
        elif dpos > 0:
            self.host = prefix
            self.is_server = True
        else:
            self.nick = prefix

        return self

    def unparse(self):
        if not (self.nick is None or self.user is None or self.host is None):
            return self.nick + "!" + self.user + "@" + self.host
        elif self.nick:
            return self.nick
        elif self.host:
            return self.host
        else:
            return None

    def __str__(self):
        if not (self.nick is None or self.user is None or self.host is None):
            return "%s!%s@%s" % (self.nick, self.user, self.host)
        elif self.nick:
            return self.nick
        elif self.host:
            return self.host
        else:
            return "(empty)"

    def __repr__(self):
        return "<IRC.Prefix: %r ! %r @ %r>" % (self.nick, self.user, self.host)

    def to_a(self):
        return [self.nick, self.user, self.host, self.is_server]

class Line(object):
    """
    An IRC protocol line.
    """
    def __init__(self, tags=None, prefix=None, cmd=None, args=None):
        self.tags = tags or {}
        self.prefix = prefix
        self.cmd = cmd
        self.args = args or []

    @classmethod
    def split(cls, line):
        """
        Split an IRC protocol line into tokens as defined in RFC 1459
        and the IRCv3 message-tags extension.
        """

        line = line.decode("utf-8", "replace")
        line = line.rstrip("\r\n").split(" ")
        i, n = 0, len(line)
        parv = []

        while i < n and line[i] == "":
            i += 1

        if i < n and line[i].startswith("@"):
            parv.append(line[i])
            i += 1
            while i < n and line[i] == "":
                i += 1

        if i < n and line[i].startswith(":"):
            parv.append(line[i])
            i += 1
            while i < n and line[i] == "":
                i += 1

        while i < n:
            if line[i].startswith(":"):
                break
            elif line[i] != "":
                parv.append(line[i])
            i += 1

        if i < n:
            trailing = " ".join(line[i:])
            parv.append(trailing[1:])

        return parv

    @classmethod
    def parse(cls, line, parse_prefix=True):
        """
        Parse an IRC protocol line into a Line object consisting of
        tags, prefix, command, and arguments.
        """

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

    @classmethod
    def join(cls, argv):
        i, n = 0, len(argv)

        if i < n and argv[i].startswith("@"):
            if " " in argv[i]:
                raise ValueError("Argument %d contains spaces: %r" % (i, argv[i]))
            i += 1

        if i < n and " " in argv[i]:
            raise ValueError("Argument %d contains spaces: %r" % (i, argv[i]))

        if i < n and argv[i].startswith(":"):
            if " " in argv[i]:
                raise ValueError("Argument %d contains spaces: %r" % (i, argv[i]))
            i += 1

        while i < n-1:
            if not argv[i]:
                raise ValueError("Argument %d is empty: %r" % (i, argv[i]))
            elif argv[i].startswith(":"):
                raise ValueError("Argument %d starts with ':': %r" % (i, argv[i]))
            elif " " in argv[i]:
                raise ValueError("Argument %d contains spaces: %r" % (i, argv[i]))
            i += 1

        parv = argv[:i]

        if i < n:
            if not argv[i] or argv[i].startswith(":") or " " in argv[i]:
                parv.append(":%s" % argv[i])
            else:
                parv.append(argv[i])

        return " ".join(parv)

    def unparse(self):
        parv = []

        if self.tags:
            tags = [k if v is True else k + b"=" + v
                for k, v in self.tags.items()]
            parv.append("@" + b",".join(tags))

        if self.prefix:
            parv.append(":" + self.prefix.unparse())

        parv.append(self.cmd)

        parv.extend(self.args)

        return self.join(parv)

    def __repr__(self):
        return "<IRC.Line: tags=%r prefix=%r cmd=%r args=%r>" % (
                        self.tags, self.prefix,
                        self.cmd, self.args)

class Connection(object):
    def __init__(self):
        self.host = None
        self.port = None
        self.ai = None
        self._fd = None
        self._file = None

    def connect(self, host, port, ssl=False):
        self.ai = socket.getaddrinfo(host, str(port), 0, socket.SOCK_STREAM)
        print(repr(self.ai))
        for af, proto, _, cname, addr in self.ai:
            self._fd = socket.socket(af, proto)
            self._fd.connect(addr)
            break
        import io
        self._fi = self._fd.makefile("rwb")

    def writeraw(self, buf):
        self._fi.write(buf+b"\r\n")
        self._fi.flush()

    def readraw(self):
        return self._fi.readline()

    def write(self, *args):
        self.writeraw(Line.join(args))

    def read(self):
        return Line.parse(self.readraw())

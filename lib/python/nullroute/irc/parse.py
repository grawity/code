# Parser for IRC protocol messages (RFC 1459 + IRCv3 message-tag extension)
#
# Note that this parser always decodes command parameters as UTF-8, which is
# what most users will end up doing anyway. This should be easy to change if
# needed.
#
# (c) 2012-2014 Mantas Mikulėnas <grawity@gmail.com>
# Released under the MIT License (dist/LICENSE.mit)

import base64
import socket
import re

class InvalidPrefixError(ValueError):
    pass

class Tags(dict):
    _ESCAPE_MAP = {";": "\\:",
                   " ": "\\s",
                   "\\": "\\\\",
                   "\r": "\\r",
                   "\n": "\\n"}

    _UNESCAPE_MAP = {":":  ";",
                     "s":  " ",
                     "\\": "\\",
                     "r":  "\r",
                     "n":  "\n"}

    def _escape(self, buf):
        out = ""
        for c in buf:
            out += self._ESCAPE_MAP.get(c, c)
        return out

    def _unescape(self, buf):
        out = ""
        esc = False
        for c in buf:
            if not esc:
                if c == "\\":
                    esc = True
                else:
                    out += c
            else:
                out += self._UNESCAPE_MAP.get(c, c)
                esc = False
        if esc:
            raise ValueError("unclosed \\ escape in tag value \"%s\"" % (buf,))
        return out

    @classmethod
    def from_bytes(cls, buf):
        return cls()._from_bytes(buf)

    def _from_bytes(self, buf):
        # Tags are required to be UTF-8.
        buf = buf.decode("utf-8", "replace")
        return self._from_str(buf)

    def _from_str(self, buf):
        for item in buf.split(";"):
            if "=" in item:
                k, v = item.split("=", 1)
                self[k] = self._unescape(v)
            else:
                self[item] = True
        return self

    def to_str(self):
        tags = []
        for k, v in self.items():
            if v is True:
                tags.append(k)
            else:
                tags.append(k + "=" + self._escape(v))
        return ";".join(tags)

    def to_bytes(self):
        return self.to_str().encode("utf-8")

    def __str__(self):
        return self.to_str()

    def __repr__(self):
        return "Tags(%s)" % super().__repr__()

class Prefix(object):
    def __init__(self, nick=None, user=None, host=None):
        self.nick = nick
        self.user = user
        self.host = host

    @classmethod
    def from_bytes(cls, buf):
        return cls()._from_bytes(buf)

    def _from_bytes(self, buf):
        # Prefix is usually ASCII-only, and should be safe to assume UTF-8,
        # so it should be safe to decode the entire thing at once.
        buf = buf.decode("utf-8", "replace")
        return self._from_str(buf)

    def _from_str(self, buf):
        if not buf:
            return self
        dpos = buf.find(".") + 1
        upos = buf.find("!") + 1
        hpos = buf.find("@", upos) + 1
        if upos == 1 or hpos == 1:
            return self
        if upos > 0:
            self.nick = buf[:upos-1]
            if hpos > 0:
                self.user = buf[upos:hpos-1]
                self.host = buf[hpos:]
            else:
                self.user = buf[upos:]
        elif hpos > 0:
            self.nick = buf[:hpos-1]
            self.host = buf[hpos:]
        elif dpos > 0:
            self.host = buf
        else:
            self.nick = buf
        return self

    def to_str(self):
        if self.nick is not None:
            res = self.nick
            if self.user is not None:
                res += "!" + self.user
            if self.host is not None:
                res += "@" + self.host
            return res
        elif self.host is not None:
            return self.host
        else:
            return ""

    def to_bytes(self):
        return self.to_str().encode("utf-8")

    def __str__(self):
        return self.to_str()

    def __repr__(self):
        return "Prefix(%r, %r, %r)" % (self.nick, self.user, self.host)

class Frame(object):
    def __init__(self, buf=None, *, tags=None, prefix=None, cmd=None, args=None):
        self.tags = tags or {}
        self.prefix = prefix
        self.cmd = cmd
        self.args = args or []
        if buf:
            self._from_bytes(buf)

    @classmethod
    def from_bytes(cls, buf, **kwargs):
        return cls()._from_bytes(buf, **kwargs)

    @classmethod
    def parse(cls, buf, **kwargs):
        return cls()._from_bytes(buf, **kwargs)

    def _from_bytes(self, buf):
        # Keep in mind that the trailing parameter *can* contain consecutive
        # spaces and those should be preserved when it is joined back. Hence
        # the manual space-skipping until we find the trailing parameter.
        #
        # (And no, we can't just look for a " :" because there can be two of
        # them in a message with @tags. This quickly gets just as complex as it
        # already is now.)

        parv = buf.rstrip(b"\r\n").split(b" ")
        i, n = 0, len(parv)

        while i < n and parv[i] == b"":
            i += 1

        if i < n and parv[i].startswith(b"@"):
            self.tags = Tags.from_bytes(parv[i][1:])
            i += 1
            while i < n and parv[i] == b"":
                i += 1

        if i < n and parv[i].startswith(b":"):
            self.prefix = Prefix.from_bytes(parv[i][1:])
            i += 1
            while i < n and parv[i] == b"":
                i += 1

        if i < n:
            self.cmd = parv[i].upper().decode("utf-8", "replace")
            i += 1
            while i < n and parv[i] == b"":
                i += 1

        while i < n:
            if parv[i].startswith(b":"):
                trailing = b" ".join(parv[i:])
                self.args.append(trailing[1:].decode("utf-8", "replace"))
                break
            elif parv[i] != b"":
                self.args.append(parv[i].decode("utf-8", "replace"))
            i += 1

        return self

    def to_bytes(self):
        parv = []
        if self.tags:
            parv.append(b"@" + self.tags.to_bytes())
        if self.prefix:
            parv.append(b":" + self.prefix.to_bytes())

        if not self.cmd:
            raise ValueError("Command cannot be empty")
        elif self.cmd.startswith(":"):
            raise ValueError("Command cannot start with colon: %r" % (self.cmd,))
        elif (" " in self.cmd) or ("\n" in self.cmd):
            raise ValueError("Command cannot contain spaces: %r" % (self.cmd,))
        else:
            parv.append(self.cmd.encode("utf-8"))

        args = [a.encode("utf-8") for a in self.args]
        for arg in args[:-1]:
            if not arg:
                raise ValueError("Non-final parameters cannot be empty: %r" % (self.args,))
            elif arg.startswith(b":"):
                raise ValueError("Non-final parameters cannot start with colon: %r" % (self.args,))
            elif (b" " in arg) or (b"\n" in arg):
                raise ValueError("Non-final parameters cannot contain spaces: %r" % (self.args,))
            else:
                parv.append(arg)
        if args:
            arg = args[-1]
            if b"\n" in arg:
                raise ValueError("Parameter cannot contain line breaks: %r" % (self.args,))
            elif (not arg) or arg.startswith(b" ") or (b" " in arg):
                parv.append(b":" + arg)
            else:
                parv.append(arg)

        return b" ".join(parv) + b"\r\n"

    def __repr__(self):
        return "Frame(tags=%r, prefix=%r, cmd=%r, args=%r)" % \
                (self.tags, self.prefix, self.cmd, self.args)

if __name__ == "__main__":
    buf = b"@ab;cd=efg\\:quux :foo@bar!baz@ohno PING  yay ab  bc :cd  ef"
    print(Frame(buf))
    print(Frame(buf).to_bytes())

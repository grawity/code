"""An object-oriented interface to .netrc files."""

# Module and documentation by Eric S. Raymond, 21 Dec 1998
# Improved to support quoted password tokens by <grawity@gmail.com>

import os, shlex, stat
from enum import Enum

__all__ = ["netrc", "NetrcParseError"]


def unquote(string):
    escape = {
        "n": "\n",
        "t": "\t",
    }
    if len(string) >= 2 and string[0] == string[-1] == "\"":
        buf, state = "", 0
        for char in string[1:-1]:
            if state == 0:
                if char == "\\":
                    state = 1
                else:
                    buf += char
            elif state == 1:
                buf += escape.get(char, char)
                state = 0
        return buf
    else:
        return string


def check_owner(fp):
    if os.name != 'posix':
        return
    prop = os.fstat(fp.fileno())
    if prop.st_uid != os.getuid():
        import pwd
        try:
            fowner = pwd.getpwuid(prop.st_uid)[0]
        except KeyError:
            fowner = 'uid %s' % prop.st_uid
        try:
            user = pwd.getpwuid(os.getuid())[0]
        except KeyError:
            user = 'uid %s' % os.getuid()
        raise NetrcParseError(
            ("~/.netrc file owner (%s) does not match"
             " current user (%s)") % (fowner, user),
            file, lexer.lineno)
    if prop.st_mode & (stat.S_IRWXG | stat.S_IRWXO):
        raise NetrcParseError(
           "~/.netrc access too permissive: access"
           " permissions must restrict access to only"
           " the owner", file, lexer.lineno)


class NetrcParseError(Exception):
    """Exception raised on syntax errors in the .netrc file."""
    def __init__(self, msg, filename=None, lineno=None):
        self.filename = filename
        self.lineno = lineno
        self.msg = msg
        Exception.__init__(self, msg)

    def __str__(self):
        return "%s (%s, line %s)" % (self.msg, self.filename, self.lineno)

class State(Enum):
    default = 0
    entry_key = 1
    entry_value = 2
    macdef_name = 3
    macdef_value = 4

class netrc(object):
    def __init__(self, file=None):
        default_netrc = file is None
        if file is None:
            try:
                file = os.path.join(os.environ['HOME'], ".netrc")
            except KeyError:
                raise OSError("Could not find .netrc: $HOME is not set")
        self.hosts = {}
        self.macros = {}
        with open(file) as fp:
            if default_netrc:
                check_owner(fp)
            self._parse(file, fp)

    def _parse(self, file, fp):
        lexer = shlex.shlex(fp)
        lexer.wordchars += r"""!#$%&'()*+,-./:;<=>?@[\]^_`{|}~"""
        state = State.default
        prev = None
        entry = {}
        while True:
            tok = lexer.get_token()
            if not tok:
                if entry:
                    self.hosts[entry.get("machine", "default")] = entry
                break
            elif state == State.default:
                if entry:
                    self.hosts[entry.get("machine", "default")] = entry
                    entry = {}
                if tok == "machine":
                    state = State.entry_value
                elif tok == "default":
                    state = State.entry_key
                elif tok == "macdef":
                    state = State.macdef_name
                else:
                    raise NetrcParseError("bad toplevel token %r" % tok,
                                          file, lexer.lineno)
            elif state == State.entry_key:
                if tok in {"login", "account", "password"}:
                    state = State.entry_value
                else:
                    lexer.push_token(tok)
                    state = State.default
                    continue
            elif state == State.entry_value:
                entry[prev] = unquote(tok)
                state = State.entry_key
            elif state == State.macdef_name:
                lexer.whitespace = " \t"
                state = State.macdef_value
            elif state == State.macdef_value:
                if tok == prev == "\n":
                    lexer.whitespace = " \t\r\n"
                    state = State.default
            else:
                raise NetrcParseError("bad state %r" % state,
                                      file, lexer.lineno)
            prev = tok

    def authenticators(self, host, allow_default=True):
        """Return a (user, account, password) tuple for given host."""
        entry = self.hosts.get(host)
        if not entry and allow_default:
            entry = self.hosts.get("default")
        if not entry:
            return None
        return (entry.get("login"),
                entry.get("account"),
                entry.get("password"))

    def __repr__(self):
        """Dump the class data in the format of a .netrc file."""
        rep = ""
        for host in sorted(self.hosts.keys()):
            entry = self.hosts[host]
            rep += "machine %s\n" % host
            for key in ["login", "account", "password"]:
                if key in entry:
                    rep += "\t%s %r\n" % (key, entry[key])
            rep += "\n"
        for macro in self.macros.keys():
            rep += "macdef %s\n" % macro
            for line in self.macros[macro]:
                rep += line
            rep += "\n"
        return rep

if __name__ == '__main__':
    print(netrc())

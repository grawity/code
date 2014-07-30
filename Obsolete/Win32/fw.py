#!python
# simple command line interface to Windows XP Firewall

from __future__ import print_function
import cmd
import sys
from nullroute.windows.firewall import Firewall
from nullroute.windows.util import load_string_resource
from subprocess import list2cmdline

def usage():
    print("Usage:")
    print("\tfw [\\\\machine] ls")
    print("\tfw [\\\\machine] enable|disable <proto>/<port> ...")
    print("\tfw [\\\\machine] add <proto>/<port> <name> [<scope>]")
    print("\tfw [\\\\machine] del <proto>/<port>")

def parse_portspec(val):
    a, b = val.lower().split("/")
    try:
        a = int(a)
    except ValueError:
        try:
            b = int(b)
        except ValueError:
            raise ValueError("Port must be an integer")
        else:
            port, proto = b, a
    else:
        port, proto = a, b

    if not 1 < port < 65535:
        raise ValueError("Port must be in range 1-65535")
    if proto not in ("tcp", "udp"):
        raise ValueError("Protocol must be TCP or UDP")

    return port, proto

class Interactive(cmd.Cmd):
    def __init__(self, machine):
        cmd.Cmd.__init__(self)
        self.prompt = "fw> "
        self.fw = Firewall(machine)

    def emptyline(self):
        pass

    def default(self, line):
        print("Unknown command %r" % line, file=sys.stderr)

    def do_EOF(self, arg):
        return True

    def do_ls(self, arg):
        entries = list(self.fw.ports.values())
        entries.sort(key=lambda e: e[self.fw.ports.POS_PORTSPEC][0])
        entries.sort(key=lambda e: e[self.fw.ports.POS_PORTSPEC][1])
        for (port, proto), scope, enabled, name in entries:
            name = load_string_resource(name)
            print(" %1s %-4s %5d %s" % ("*" if enabled else "", proto, port, name))

    def do_enable(self, arg):
        specs = [parse_portspec(a) for a in arg.split()]
        for portspec in specs:
            self.fw.ports.set_rule_status(portspec, True)

    def do_disable(self, arg):
        specs = [parse_portspec(a) for a in arg.split()]
        for portspec in specs:
            self.fw.ports.set_rule_status(portspec, False)

    def do_rename(self, arg):
        spec, newname = arg.split(None, 1)
        spec = parse_portspec(spec)
        oldname = self.fw.ports[spec]
        if oldname.startswith("@"):
            print("Warning: Renaming built-in rule", oldname)
        self.fw.ports[spec]

try:
    if sys.argv[1].startswith("\\\\"):
        machine = sys.argv.pop(1)
    else:
        machine = None
except IndexError:
    machine = None

interp = Interactive(machine)

if len(sys.argv) > 1:
    interp.onecmd(list2cmdline(sys.argv[1:]))
else:
    interp.cmdloop()

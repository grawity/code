#!/usr/bin/env python3
import os
import subprocess
import sys
from urllib.parse import (quote as urlencode,
                        unquote as urldecode)

pinentry = "pinentry-gtk-2"
args = ["--no-global-grab"]

action = "GETPIN"
config = [
    # Note: SETPROMPT is mandatory, even if empty
    "SETTITLE %s" % urlencode("A dialog for entering something"),
    "SETDESC %s" % urlencode("You need to enter something."),
    "SETPROMPT %s" % urlencode("Enter something:"),
    #"SETOK %s" % urlencode("Yeah"),
    #"SETCANCEL %s" % urlencode("Nope"),
]

if tty := os.environ.get("GPG_TTY"):
    args += ["--ttyname", tty]
# I don't recall whether I needed these?
#args += ["--lc-ctype", ...]
#args += ["--lc-messages", ...]
#config += ["OPTION lc-ctype %s" % ...]
#config += ["OPTION lc-messages %s" % ...]

config += [action]
with subprocess.Popen([pinentry, *args],
                      stdin=subprocess.PIPE,
                      stdout=subprocess.PIPE) as proc:
    for line in proc.stdout:
        status, _, rest = line.decode().rstrip().partition(" ")
        if len(config):
            # State = configuring
            if status == "OK":
                line = (config.pop(0) + "\n").encode()
                proc.stdin.write(line)
                proc.stdin.flush()
            else:
                proc.kill()
                sys.exit("Agent error while configuring: %r" % rest)
        else:
            # State = waiting for input
            if status == "OK":
                # Null input submitted by user
                proc.kill()
                sys.exit(0)
            elif status == "D":
                print(urldecode(rest))
                proc.kill()
                sys.exit(0)
            elif status == "ERR":
                proc.kill()
                if rest.startswith("83886179 "):
                    # Error 0x5000063 (Pinentry, Operation cancelled)
                    if action == "CONFIRM":
                        sys.exit(1)
                    else:
                        sys.exit("User cancelled input prompt")
                else:
                    sys.exit("Agent error: %r" % rest)
            else:
                proc.kill()
                sys.exit("Protocol error: %r" % line)

#!/usr/bin/env python
import os, sys, re

def load_mappings(path):
    mappings = []
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if (not line) or line.startswith("#"):
                continue
            line = line.split()
            line[0] = re.compile("^%s$" % line[0])
            mappings.append(line)
    return mappings

def find_mapping(mappings, uri):
    print("looking up %r" % uri)
    for regex, replace, *rest in mappings:
        print("considering %r / %r" % (regex, replace))
        m = regex.match(uri)
        if m:
            print("matched")
            return subst(replace, m)
    return uri

def subst(template, match):
    state = 0
    output = ""
    buf = ""
    states = {
        0: [
            ("$",          None,                           None,         1),
            (None,         lambda: char,                   None,         0),
        ],
        1: [
            ("0123456789", lambda: match.group(int(char)), None,         0),
            ("&",          lambda: match.group(0),         None,         0),
            ("{",          None,                           lambda: None, 2),
            (None,         lambda: "$" + char,             None,         0),
        ],
        2: [
            ("0123456789", None,                           lambda: char, 2),
            ("}",          lambda: match.group(int(buf)),  None,         0),
            (None,         lambda: "${" + buf + char,      None,         0),
        ],
    }

    for char in template:
        for test_chars, add_output, add_buf, new_state in states[state]:
            if test_chars is None or char in test_chars:
                if add_output:
                    r = add_output()
                    if r:
                        output += r
                    else:
                        output = ""
                if add_buf:
                    r = add_buf()
                    if r:
                        buf += r
                    else:
                        buf = ""
                state = new_state
                break
    return output

    for char in template:
        print("* %r [%r]" % (char, state))
        if state == 0:
            if char == "$":
                state = 1
            else:
                output += char
        elif state == 1:
            if char in "0123456789":
                output += match.group(int(char))
                state = 0
            elif char == "&":
                output += match.group(0)
                state = 0
            elif char == "{":
                buf = ""
                state = 2
            else:
                output += "$" + char
                state = 0
        elif state == 2:
            if char in "0123456789":
                buf += char
            elif char == "}":
                output += match.group(int(buf))
                state = 0
            else:
                output += "${" + buf + char
                state = 0
    return output

conf_path = os.path.expanduser("~/lib/uri")
mappings = load_mappings(conf_path)

for uri in sys.argv[1:]:
    tmp = ""
    while tmp != uri:
        tmp = uri
        uri = find_mapping(mappings, tmp)
    print(uri)

#!/usr/bin/env python
import sys
import json

import irc

def parse_test(file):
    for line in open(file):
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        yield json.loads("[%s]" % line)

def run_test(file, func):
    passed, failed = 0, 0
    for input, wanted_output in parse_test(file):
        actual_output = func(input)
        if hasattr(actual_output, "decode"):
            actual_output = actual_output.decode().rstrip("\r\n")
        if wanted_output == actual_output:
            msg = " OK "
            passed += 1
        else:
            msg = "FAIL"
            failed += 1
        print("%s: %r -> %s" % (msg, input, json.dumps(actual_output)))
        if msg == "FAIL":
            print("\033[33m%s: %r -> %s\033[m" % ("WANT",
                input, json.dumps(wanted_output)))
    print("Tests: %s passed, %d failed" % (passed, failed))
    return failed

def test_split(input):
    input = input.encode("utf-8")
    try:
        return irc.Frame.split(input)
    except ValueError:
        return None

def test_join(input):
    try:
        return irc.Frame.join(input)
    except ValueError:
        return None

def test_prefix_split(input):
    try:
        p = irc.Prefix.parse(input)
        if p:
            return p.to_a()
        else:
            return None
    except ValueError:
        return None

def test_parse(input):
    input = input.encode("utf-8")
    p = irc.Frame.parse(input)
    tags = [k if v is True or v == "" else "%s=%s" % (k, v)
        for k, v in p.tags.items()]
    if tags:
        tags.sort()
    else:
        tags = None
    if p.prefix:
        prefix = p.prefix.to_a()
    else:
        prefix = None
    return [tags, prefix, p.args]

dir = "../tests"

f = 0
f += run_test(dir+"/irc-split.txt", test_split)
f += run_test(dir+"/irc-join.txt", test_join)
f += run_test(dir+"/irc-prefix-split.txt", test_prefix_split)
f += run_test(dir+"/irc-parse.txt", test_parse)

print("Total: %d failed" % f)

sys.exit(f > 0)

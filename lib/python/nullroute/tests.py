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
	for input, output in parse_test(file):
		testout = func(input)
		if output == testout:
			msg = " OK "
			passed += 1
		else:
			msg = "FAIL"
			failed += 1
		print("%s: %r -> %s" % (msg, input, json.dumps(testout)))
	print("Tests: %s passed, %d failed" % (passed, failed))
	return failed

def test_split(input):
	input = input.encode("utf-8")
	try:
		output = irc.Line.split(input)
	except ValueError:
		return None
	else:
		return [p.decode("utf-8", "replace") for p in output]

def test_join(input):
	try:
		return irc.Line.join(input)
	except ValueError:
		return None

dir = "../.."

f = 0
f += run_test(dir+"/test-irc-parse.json", test_split)
f += run_test(dir+"/test-irc-unparse.json", test_join)

sys.exit(f > 0)

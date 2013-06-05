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
		if wanted_output == actual_output:
			msg = " OK "
			passed += 1
		else:
			msg = "FAIL"
			failed += 1
		print("%s: %r -> %s" % (msg, input, json.dumps(actual_output)))
	print("Tests: %s passed, %d failed" % (passed, failed))
	return failed

def test_split(input):
	input = input.encode("utf-8")
	try:
		return irc.Line.split(input)
	except ValueError:
		return None

def test_join(input):
	try:
		return irc.Line.join(input)
	except ValueError:
		return None

dir = "../.."

f = 0
f += run_test(dir+"/test-irc-split.txt", test_split)
f += run_test(dir+"/test-irc-join.txt", test_join)

print("Total: %d failed" % f)

sys.exit(f > 0)

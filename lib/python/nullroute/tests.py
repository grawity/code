#!/usr/bin/env python
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
			print(" OK : %r -> %r" % (input, testout))
			passed += 1
		else:
			print("FAIL: %r -> %r" % (input, testout))
			failed += 1
	print("Tests: %s passed, %d failed" % (passed, failed))

def test_join(input):
	try:
		return irc.Line.join(input)
	except ValueError:
		return None

run_test("../../test-irc-unparse.json", test_join)

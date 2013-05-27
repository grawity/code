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
run_test(dir+"/test-irc-parse.json", test_split)
run_test(dir+"/test-irc-unparse.json", test_join)

#!/usr/bin/env php
<?php

require "irc.php";

function parse_test($file) {
	$tests = array();
	$fh = fopen($file, "r");
	while (($line = fgets($fh)) !== false) {
		$line = trim($line);
		if (!strlen($line) || substr($line, 0, 2) == "//")
			continue;
		$tests[] = json_decode("[$line]");
	}
	fclose($fh);
	return $tests;
}

function run_test($file, $func) {
	$passed = $failed = 0;
	foreach (parse_test($file) as $test) {
		list($input, $wanted_output) = $test;
		$actual_output = $func($input);
		if ($wanted_output === $actual_output) {
			$msg = " OK "; $passed++;
		} else {
			$msg = "FAIL"; $failed++;
		}
		print "$msg: ".json_encode($input).
			" -> ".json_encode($actual_output)."\n";
	}
	print "Tests: $passed passed, $failed failed\n";
	return $failed;
}

$dir = "../tests";
$f = 0;

$f += run_test("$dir/irc-split.txt", function($input) {
	return IRC\Line::split($input);
});

$f += run_test("$dir/irc-join.txt", function($input) {
	return IRC\Line::join($input);
});

print "Total: $f failed\n";

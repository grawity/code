#!/usr/bin/env perl

use Nullroute::Lib;

sub test_sep {
	print "\n-- @_ --\n\n";
}

sub child (&) {
	if (my $p = fork) {
		waitpid($p, 0);
	} else {
		exit shift->();
	}
}

sub foo { bar(); }
sub bar { baz(); }
sub baz { test_log(); }
sub test_log {
	_debug("debug message");
	_info("info message");
	_log("log message");
	_log2("log2 message");
	_notice("notice message");
	_warn("warning message");
	_err("error message");
	_die("fatal message");
}

test_sep("messages (normal)");

$::debug = 0; child { foo() };

test_sep("messages (debug)");

$::debug = 1; child { foo() };

test_sep("messages (debug 2)");

$::debug = 2; child { foo() };

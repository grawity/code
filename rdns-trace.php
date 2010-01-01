#!/usr/bin/php
<?php
# rdns-trace - reverse DNS tracing, sort of

# (c) 2009 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
#
# <http://purl.oclc.org/NET/grawity/code.html>

# Requires dns_get_record() - so at least PHP 5.3.0 on Windows.

error_reporting(-1); // use strict;

if (isset($_SERVER["REMOTE_ADDR"])) {
	header("Content-Type: text/plain; charset=utf-8");
	header("Last-Modified: " . date("r", filemtime(__FILE__)));
	readfile(__FILE__);
	die;
}

function usage() {
	print "Usage: rdns-trace [-cC] <address> [<address> ...]\n";
	return 2;
}

# check if argument is an IP address
function is_inetaddr($a) {
	return @inet_pton($a) !== false;
}

function is_inet4addr($a) {
	return ($p = @inet_pton($a)) !== false and strlen($p) == 4;
}

function is_inet6addr($a) {
	return ($p = @inet_pton($a)) !== false and strlen($p) == 16;
}

# convert IP address to .arpa domain for PTR
function toptr($ip) {
	$packed = @inet_pton($ip);
	if ($packed === false) {
		return false;
	}
	elseif (strlen($packed) == 4) {
		$ip = unpack("C*", $packed);
		$suffix = ".in-addr.arpa.";
	}
	elseif (strlen($packed) == 16) {
		$ip = unpack("H*", $packed);
		$ip = str_split($ip[1]);
		$suffix = ".ip6.arpa.";
	}
	else {
		return false;
	}

	return implode(".", array_reverse($ip)) . $suffix;
}

# Do DNS requests
function resolve($addr) {
	if (is_inetaddr($addr)) {
		$addr = toptr($addr);
		$rr = dns_get_record($addr, DNS_PTR);
	}
	else {
		$rr = dns_get_record($addr, DNS_CNAME);
		if (empty($rr))
			$rr = dns_get_record($addr, DNS_A | DNS_AAAA);
	}

	$addresses = array();
	if (empty($rr))
		return $addresses;
		
	foreach ($rr as $record) {
		if (isset($record["ip"]))
			$addresses[] = $record["ip"];
		elseif (isset($record["ipv6"]))
			$addresses[] = $record["ipv6"];
		elseif (isset($record["target"]))
			$addresses[] = $record["target"];
	}

	return $addresses;
}

# Colourize the provided string.
# IP addresses are detected automatically if $colour not given
function colour($addr, $c = 0) {
	 if ($GLOBALS["use_colour"] == false)
		return $addr;

	if ($c > 0)
		;
	elseif (is_inet4addr($addr))
		$c = 35;
	elseif (is_inet6addr($addr))
		$c = 36;
	else
		$c = 33;
	
	return "\033[{$c}m" . $addr . "\033[m";
}

# This is where the fun happens.
function go($from, $depth = 0, $skip = array()) {
	global $visited;
	$visited[] = $from;

	# print current address
	print str_repeat(" ", $depth*3) . colour($from) . " = ";

	$addresses = resolve($from); sort($addresses);

	if (empty($addresses))
		print colour("(none)", 31);
	else
		print implode(", ", $addresses);
	print "\n";

	# recursively look up the results
	foreach ($addresses as $addr) {
		$addr = strtolower($addr);

		if (in_array($addr, $visited) or in_array($addr, $skip))
			continue;
		$visited[] = $addr;

		go($addr, $depth+1, $skip+$addresses);
	}
}

$TERM = getenv("TERM");
$use_colour = !($TERM === false or $TERM == "dumb");

$addresses = array();

# Fucking getopt() doesn't let me grab the rest of $argv
for ($i = 1; $i < $argc; $i++) {
	$arg = $argv[$i];
	if (empty($arg)) continue;

	if ($arg[0] == "-") switch ($arg) {
		case "-h":
		case "--help":
			exit(usage());
		
		case "-c":
			$use_colour = true;
			break;

		case "-C":
			$use_colour = false;
			break;

		default:
			print "Unknown option $arg\n";
			exit(usage());
	}

	else {
		$addresses[] = $arg;
	}
}

if (count($addresses) == 0)
	exit(usage())

$i = 0; foreach ($addresses as $start_addr) {
	$visited = array();
	if ($i++ > 0) print "\n";
	go($start_addr);
}

#!/usr/bin/php
<?php
define("STARTED", time());

require "./config.php";

function noop() { }

function err($message, $exitval=0) {
	fwrite(STDERR, $message."\n");
	if ($exitval) exit($exitval);
}

function putlog(/*$format, @args*/) {
	$args = func_get_args();
	$format = array_shift($args)."\n";
	vprintf($format, $args);
	#global $log; vfprintf($log, $format, $args);
}

function gets() {
	global $socket;
	if (!is_resource($socket))
		err("[net read] Socket closed", 1);
	$line = fgets($socket);
	if ($line === false)
		return false;
	$line = rtrim($line);
	if (DEBUG) echo "<-- $line\n";
	return $line;
}

function putsf(/*$format, @args*/) {
	global $socket;
	if (!is_resource($socket))
		err("[net write] Socket closed", 1);
	$args = func_get_args();
	$format = array_shift($args);
	$str = vsprintf($format, $args);
	fwrite($socket, $str."\n");
	if (DEBUG) echo "--> $str\n";
}
function puts(/*@args*/) {
	global $socket;
	if (!is_resource($socket))
		err("[net write] Socket closed", 1);
	$args = func_get_args();
	$str = implode(" ", $args);
	fwrite($socket, $str."\n");
	if (DEBUG) echo "--> $str\n";
}

function linked() { global $linking; return !$linking; }

require "./base64.php";
require "./address.class.php";
require "./parse.php";
require "./botnet_in.php";
require "./botnet_out.php";
require "./events.php";

$botnet = array();
$partyline = array();

$link_url = ($link_ssl?"ssl":"tcp")."://{$link_host}:{$link_port}";

$socket = stream_socket_client($link_url, $errno, $errstr);
if (!$socket)
	err("[stream] $errno $errstr", 1);

putlog("connected to %s:%s", $link_host, $link_port);

puts($my_handle);

do {
	$in = gets();
	if ($in == "You don't have access.")
		err("[link] '$my_handle' not recognized by remote", 1);
	elseif (substr($in, -1) == "\x01")
		err("[link] User '$my_handle' lacks +b flag in remote", 1);
	elseif (substr($in, 0, 8) == "passreq ")
		break;
	elseif ($in == "*hello!") {
		putlog("[auth] Skipped authentication");
		goto logged_in;
	}
} while (true);

$challenge = strstr($in, "<");

if (!$challenge)
	err("[auth] Remote does not support MD5 authentication", 1);

if (USE_CHALLENGE) {
	putlog("Authenticating (MD5)");
	$response = md5($challenge.$link_pass);
	puts("digest $response");
}
else {
	putlog("Authenticating (plain)");
	puts($link_pass);
}

switch(gets()) {
case '*hello!':
	goto logged_in;
case 'badpass':
	err("[auth] Password rejected", 1); 
	break;
default:
	err("[auth] Unknown response", 1);
}

logged_in:
$linking = true;
$last_recv_ping = 0;
$last_sent_ping = 0;

stream_set_timeout($socket, 5);

while (true) {
	if (time() - $last_sent_ping > 5)
		send_ping();
	
	/*
	$read = array($socket);
	$write = $except = null;
	$actstreams = stream_select($read, $write, $except, 5, 0);
	if ($actstreams === false)
		err("[select] fucked up\n", 1);
	elseif ($actstreams == 0)
		continue;
	*/
	
	$in = gets();
	if ($in == "")
		continue;
	
	$in_cmd = strtok($in, " ");
	$in_args = strtok("");

	if (array_key_exists($in_cmd, $botnet_commands)) {
		$handler = $botnet_commands[$in_cmd];
		$handler($in_cmd, $in_args);
	}
	else {
		putlog("(unknown) %s", $in);
	}
}

fclose($socket);

#!/usr/bin/php
<?php

class addr {
	public $idx, $handle, $bot;
	
	function __construct($str=null) {
		if (!strlen($str)) return;
		if ($p = strpos($str, ":")) {
			$this->idx = (int) substr($str, 0, $p);
			$str = substr($str, ++$p);
		}
		if ($p = strpos($str, "@")) {
			$this->handle = substr($str, 0, $p);
			$str = substr($str, ++$p);
		}
		$this->bot = $str;
	}
	
	function __toString() {
		if ($this->idx !== null)
			return "{$this->idx}:{$this->handle}@{$this->bot}";
		elseif ($this->handle !== null)
			return "{$this->handle}@{$this->bot}";
		else
			return $this->bot;
	}
}
function hb($addr) {
	if (is_string($addr))
		$addr = new addr($addr);
		
	if ($addr->handle !== null)
		return "{$addr->handle}@{$addr->bot}";
	else
		return $addr->bot;
}

function eggnet_parse($instr, $args) {
	$args = explode(",", $args);
	$in = explode(" ", $instr, count($args));
	$out = array();
	foreach ($args as $i => $type) {
		$res = null;
		$invalue = $in[$i];
		# * prefix for a type means the value is prefixed by privilege level
		if ($type[0] == "*") {
			$type = substr($type, 1);
			$flag = $invalue[0];
			$invalue = substr($invalue, 1);
		}
		else $flag = null;
		
		switch ($type) {
			case "i:h@b": # idx:handle@bot
				$res = new addr();
				list ($invalue, $res->bot) = explode("@", $invalue, 2);
				list ($res->idx, $res->handle) = explode(":", $invalue, 2);
				break;
			case "h@b": # handle@bot
				$res = new addr();
				if ($pos = strpos($invalue, ":")) $invalue = substr($invalue, $pos+1);
				list ($res->handle, $res->bot) = explode("@", $invalue, 2);
				break;
			case "str": # string
				$res = $invalue;
				break;
			case "int":
				$res = btoi($invalue);
				break;
			case "int10": # integer (decimal)
				$res = intval($invalue, 10);
				break;
		}
		
		if ($flag !== null)
			$out[] = array($flag, $res);
		else
			$out[] = $res;
	}
	return $out;
}

function parse_route($route) {
	$route = explode(":", substr($route, 1));
	$timestamp = array_shift($route);
	return array($timestamp, $route);
}

require "eggnet_base64.php";

function err($text = "", $exitval = 0) {
	fwrite(STDERR, $text."\n");
	if ($exitval) exit($exitval);
}

function plog(/*$format, @args*/) {
	$args = func_get_args();
	$format = array_shift($args);
	$str = vsprintf($format, $args);
	print "$str";
}

function putsf(/*$format, @args*/) {
	$args = func_get_args();
	$format = array_shift($args);
	$str = vsprintf($format, $args);
	puts($str);
}
function puts(/*@args*/) {
	global $sh;
	$args = func_get_args();
	$str = implode(" ", $args);
	fwrite($sh, $str."\n");
	if (DEBUG) echo "--> $str\n";
}
function gets() {
	global $sh;
	$line = fgets($sh);
	if ($line === false)
		return false;
	$line = rtrim($line);
	if (DEBUG) echo "<-- $line\n";
	return $line;
}

require "eggnet_netcmds.php";
require "eggnet_rcmds.php";
require "eggnet_handlers.php";

$botnet = array();

$options = array(
	'DEBUG' => false,
	'USE_CHALLENGE' => true,
);

array_shift($argv);
foreach ($argv as $arg) {
	$option = substr($arg, 1);
	switch ($arg[0]):
	case "-":
		$value = false; break;
	case "+":
		$value = true; break;
	default:
		$option = strtok($option, "=");
		$value = strtok("");
	endswitch;
		
	switch ($option):
	case "d": $options["DEBUG"] = $value; break;
	endswitch;
}

foreach ($options as $key => $value)
	define($key, $value);

$link_host = "nullroute.eu.org"; $link_port = 29159;
#$link_host = "127.0.0.1"; $link_port = 3333;
$link_ssl = false;

$my_handle = 'foobie';
$link_password = 'bletch';

$my_useragent = "foodrop v1.3.37";

$link_url = ($link_ssl?"ssl":"tcp")."://{$link_host}:{$link_port}";

$sh = stream_socket_client($link_url, $errno, $errstr);
if (!$sh)
	err("[stream] {$streamErr} {$streamErrStr}", 1);

echo "Introducing\n";
puts($my_handle);

do {
	$in = gets();
	if ($in == "You don't have access.")
		err("[link] not recognized by remote host", 1);
	elseif (substr($in, -1) == "\x01")
		err("[link] '$my_handle' lacks +b flag", 1);
	elseif (substr($in, 0, 8) == "passreq ")
		break;
} while (true);

strtok($in, " ");
$challenge = strtok($in);

if ($challenge and USE_CHALLENGE) {
	plog("[connect] Authenticating (MD5)\n");
	$response = md5($challenge.$link_password);
	puts("digest $response");
}
else {
	plog("[connect] Authenticating (plain)\n");
	puts($link_password);
}
switch(gets()) {
case '*hello!':
	plog("[auth] Logged in\n");
	break;
case 'badpass':
	err("[auth] password rejected", 1); 
	break;
default:
	err("[auth] unknown response", 1);
}

$linking = true;
$last_recv_ping = 0;
$last_send_ping = time();
stream_set_timeout($sh, 5);

while (true):
	/*
	$read = array($sh);
	$write = $except = null;
	$actstreams = stream_select($read, $write, $except, 5, 0);
	if ($actstreams === false)
		err("[select] fucked up\n", 1);
	*/
		
	if (time() - $last_send_ping > 5)
		send_ping();

	/*
	if ($actstreams == 0)
		continue;
	*/
	
	$in = gets();
	$in_cmd = strtok($in, " ");
	$in_arg = strtok("");

	switch ($in_cmd):
	case "": break;
	case "a":	rcmd_actchan($in_arg); break;
	case "*bye": # unlink ack
		err("Unlinked.\n", 1);
		break;
	case "bye": # unlink req
		$reason = $in_arg;
		err("Unlinked by remote: $reason\n", 1);
		break;
	case "c":	rcmd_chan($in_arg); break;
	case "ct":	rcmd_chat($in_arg); break;
	case "el":
		$linking = false;
		h_bot_linked($remote_handle, $my_handle);
		break;
	case "error":
		rcmd_error($in_arg); break;
	case "handshake":
		rcmd_handshake($in_arg); break;
	case "i?":	rcmd_infop($in_arg); break;
	case "j":	rcmd_join($in_arg); break;
	case "m":	rcmd_motd($in_arg); break;
	case "n":	rcmd_nlinked($in_arg); break;
	case "pi":
		$last_recv_ping = time();
		puts("po");
		break;
	case "po":	break;
	case "p":	rcmd_priv($in_arg); break;
	case "pt":	rcmd_part($in_arg); break;
	case "r":	rcmd_reject($in_arg); break;
	case "t":	rcmd_trace($in_arg); break;
	case "td":	rcmd_traced($in_arg); break;
	case "tb":	rcmd_thisbot($in_arg); break;
	case "un":	rcmd_unlinked($in_arg); break;
	
	case "ul":
		# unlink requested
		$a = scan($in_arg, "source:ihb", "nexthop:str", "dest:str");
		plog("[botnet] unlink req: %s (by %s)\n", $a->dest, $a->source);
		break;
	
	case "version":
		rcmd_version($in_arg); break;
	case "w":	rcmd_who($in_arg); break;
	case "z":	rcmd_zapf($in_arg); break;
	default:
		echo "<<< ", $in, "\n";
	
	endswitch;
endwhile;

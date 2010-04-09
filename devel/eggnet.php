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
			$levelsign = $invalue[0];
			$invalue = substr($invalue, 1);
		}
		else $levelsign = null;
		
		switch ($type) {
			case "i:h@b": # idx:handle@bot
				$res = new addr();
				list ($invalue, $res->bot) = explode("@", $invalue, 2);
				list ($res->idx, $res->handle) = explode(":", $invalue, 2);
				break;
			case "h@b": # handle@bot
				$res = new addr();
				list ($res->handle, $res->bot) = explode("@", $invalue, 2);
				break;
			case "str": # string
				$res = $invalue;
				break;
			case "int": # integer (base64 in newnet mode)
				$res = btoi($invalue);
				break;
			case "int10": # integer (decimal)
				$res = intval($invalue, 10);
				break;
			case "b64": # integer (base64)
				$res = b64_int($invalue);
				break;
		}
		
		if ($levelsign !== null)
			$out[] = array($levelsign, $res);
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

function btoi($in) {
	global $newnet;
	return $newnet? b64_int($in) : intval($in, 10);
}
function itob($in) {
	global $newnet;
	return $newnet? int_b64($in) : (string)$in;
}

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
	'USE_NEWNET' => true,
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
	case "n": $options["USE_NEWNET"] = $value; break;
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

$newnet = USE_NEWNET and $challenge;

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
	
	case "actchan": case "a":
		rcmd_actchan($in_arg); break;
	
	case "*bye":
		# unlink ack
		err("Unlinked.\n", 1);
		break;
	
	case "bye":
		# unlink request
		$reason = $in_arg;
		err("Unlinked by remote: $reason\n", 1);
		break;
	
	case "chan": case "c":
		rcmd_chan($in_arg); break;
	
	case "chat": case "ct":
		# message by a bot
		$a = scan($in_arg, "source:str", "msg:str");
		
		printf("[bot] *%s* %s\n", $a->source, $a->msg);
		break;
	
	case "el":
		# end link
		# ()
		$linking = false;
		
		h_bot_linked($remote_handle, $my_handle);
		break;
	
	case "error":
		rcmd_error($in_arg); break;
	
	case "info?": case "i?":
		rcmd_infop($in_arg); break;
	
	case "join": case "j":
		rcmd_join($in_arg); break;

	case "motd": case "m":
		rcmd_motd($in_arg); break;
	
	case "n":
		rcmd_nlinked($in_arg, true); break;
		
	case "nlinked":
		rcmd_nlinked($in_arg, false); break;
	
	case "ping": case "pi":
		$last_recv_ping = time();
		puts($newnet?"po":"pong");
		break;
	
	case "pong": case "po":
		break;
	
	case "priv": case "p":
		# bot_privmsg (src_bot, dest_ihb, *text)
		$a = scan($in_arg, "source:ihb", "dest:str", "msg:str");
		if (strpos($a->dest, ":@")) {
			list ($handle, $bot) = explode("@", $a->dest);
			$a->dest = new addr("$handle@$bot");
			plog("[note] (%s@%s -> %s@%s) %s\n", $a->source->handle, $a->source->bot, $a->dest->handle, $a->dest->bot, $a->msg);
			h_note($a->source, $a->dest, $a->msg);
		}
		else {
			plog("[priv] (%s -> %s) %s\n", $a->source, $a->dest, $a->msg);
		}
		break;
	
	case "reject": case "r":
		rcmd_reject($in_arg); break;
	
	case "trace": case "t":
		# trace (src_ihb, dest_bot, path)
		$a = scan($in_arg, "user:ihb", "dest:str", "path:str");
		h_trace($a->user, $a->dest, $a->path);
		break;
	
	case "traced": case "td":
		# traced (src_ihb, path)
		$a = scan($in_arg, "user:ihb", "path:str");
		h_trace_reply($a->user, $a->path);
		break;
	
	case "thisbot": $newnet = false;
	case "tb":
		rcmd_thisbot($in_arg); break;
	
	case "un":
		# bot unlinked (bot, notice)
		$a = scan($in_arg, "bot:str", "text:str");
		h_bot_unlinked($a->bot);
		break;
	
	case "unlinked":
		$a = scan($in_arg, "bot:str");
		h_bot_unlinked($a->bot);
		break;		
	
	case "unlink": case "ul":
		# unlink requested
		$a = scan($in_arg, "source:ihb", "nexthop:str", "dest:str");
		plog("[botnet] unlink req: %s (by %s)\n", $a->dest, $a->source);
		break;
	
	case "version":
		rcmd_version($in_arg); break;
	
	case "who": case "w":
		# remote who (src_ihb, dest_bot, channel)
		$a = scan($in_arg, "source:ihb", "dest:str", "channel:int");
		
		printf("[who?] %s -> %s (channel %d)\n", $a->source, $a->dest, $a->channel);
		#if ($a->dest == $my_handle) {
		#	foreach (explode("\n", `qwinsta`) as $line)
		#		cmd_priv($a->source, preg_replace('|^>|', '*', $line));
		#}
		break;
	
	default:
		echo "<<< ", $in, "\n";
	
	endswitch;
endwhile;


/*
	
case 'nlinked': case 'nl':
	$handle = snip($in);
	$thru = snip($in);
	$version = snip($in);
	$share = $version[0] == '+';
	bot($handle);
	bot($thru);
	$botnet[$handle]["downlink"] = $thru;
	$botnet[$thru]["uplinks"][] = $handle;
	
	echo "Uplinked: {$handle} (through {$thru})\n";
	
	break;

case 'idle': case 'i':
	$handle = snip($in);
	$idx = snip($in); $idx = $Newnet? b64toint($idx) : intval($idx);
	$time = snip($in); $time = $Newnet? b64toint($time) : intval($time);
	echo "Idle: {$handle} [{$idx}] = {$time}\n";

default:
	e("\033[31mtodo: [{$cmd}] {$in}\033[m");

endswitch;

#sleep(1);

endwhile;

*/
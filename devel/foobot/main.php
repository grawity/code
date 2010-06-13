#!/usr/bin/php
<?php
require "config.inc";

function socket_printf(/*$socket, $format, @args*/) {
	$_ = func_get_args();
	$socket = array_shift($_);
	$format = array_shift($_);
	$args = $_;
	
	$data = vsprintf($format, $args);
	return socket_write($socket, $data);
}

require "H:/code/socket_gets.inc";
require "irc-commands.inc";
require "irc-events.inc";
require "irc-output.inc";

class Address {
	public $nick = null;
	public $user = null;
	public $host = null;

	public function __construct($nick=null) {
		if ($nick === null) return;
		if (strpos($nick, "@") and strpos($nick, "@")) {
			list ($this->nick, $this->user) = explode("!", $nick, 2);
			list ($this->user, $this->host) = explode("@", $this->user, 2);
		}
		else {
			$this->host = $nick;
		}
	}
	public function __toString() {
		if (!strlen($this->host))
			return null;
		elseif (!(strlen($this->nick) and strlen($this->user)))
			return $this->host;
		else
			return "{$this->nick}!{$this->user}@{$this->host}";
	}
}

function irc_split($in) {
	if ($in === null) return;

	if (strpos($in, " :") !== false)
		list ($in, $final) = explode(" :", $in, 2);
	else
		$final = null;
	$in = explode(" ", $in);
	if ($final !== null) $in[] = $final;

	if ($in[0][0] == ":")
		$addr = new Address(substr(array_shift($in), 1));
	else
		$addr = null;
	$cmd = strtoupper(array_shift($in));

	return array($addr, $cmd, $in);
}

function irc_join($args) {
	$last = &$args[count($args)-1];
	if (strpos($last, " ") !== false)
		$last = ":".$last;
	return implode(" ", $args);	
}
function irc_joinv(/*@args*/) { return irc_join(func_get_args()); }

function irc_tolower($str) { return strtr(strtolower($str), '[\\]', '{|}'); }

$socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
socket_connect($socket, IRC_HOST, IRC_PORT);

function register($s) {
	if (IRC_PASSWORD !== null)
		socket_printf($s, "PASS %s\n", IRC_PASSWORD);
	socket_printf($s, "USER %s %s %s :%s\n", IRC_USER, "a", "a", IRC_REALNAME);
	socket_printf($s, "NICK %s\n", IRC_NICK);
}

register($socket);

while (true) {
	$in = socket_gets($socket);
	if (!strlen($in))
		break;

	$in = rtrim($in);
	list ($addr, $cmd, $args) = irc_split($in);

	if (array_key_exists($cmd, $irc_commands)) {
		$handler = &$irc_commands[$cmd];
		if ($handler === null)
			continue;

		$out = $handler($addr, $args);
		if ($out === false)
			break;
		elseif (strlen($out))
			socket_write($socket, $out);
	}
	else {
		print "Unhandled: $in\n";
	}
}

socket_close($socket);

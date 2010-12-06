#!/usr/bin/php
<?php
/* From the impossibly-useless-projects dept.
 *
 * eggnat - gateway for eggdrop botnets
 * 
 * - Allows linking using another bot's identity
 * - Allows linking other bots if you're marked as "leaf"
 */

set_include_path(implode(PATH_SEPARATOR, array(
	get_include_path(),
	getenv("HOME")."/code/useless/eggnet",
	getenv("HOME")."/lib",
)));

require "base64.php";

class Config {
	static $fake_handle = "defense";
	static $fake_leaf = true;
	static $link = "tcp://collinp.com:6512";
	static $link_starttls = false;
	static $listen = "tcp://[::1]:6512";

	// max idxs per bot until everything fucks up
	static $idx_mux_multiplier = 0x80;
}
class State {
	static $in_stream;
	static $out_stream;
	static $downlink = array();
	static $real_handle = null;
	static $authed = 0;
}

function fixup_idx($bot, $idx, $encode=true) {
	$mult = &Config::$idx_mux_multiplier;

	if ($encode) $idx = btoi($idx);
	if ($idx >= $mult) {
		print "warning: idx_mux_multiplier too low to mux $bot:$idx\n";
	}
	$offset = array_search($bot, State::$downlink, true) * $mult;
	$new = $idx + $offset;
	return $encode?itob($new):$new;
}
function unfixup_idx($idx, $encode=true) {
	$mult = &Config::$idx_mux_multiplier;

	if ($encode) $idx = btoi($idx);
	$new = $idx % $mult;
	$botnum = ($idx-$new) / $mult;
	$bot = State::$downlink[$botnum];
	return array($bot, $encode?itob($new):$new);
}

function split_ihb($ihb) {
	$idx = strtok($ihb, ":");
	$hand = strtok("@");
	$bot = strtok(null);
	return array($idx, $hand, $bot);
}
function fixup_ihb($ihb) {
	list ($idx, $hand, $bot) = split_ihb($ihb);
	$idx = fixup_idx($bot, $idx, false);
	$bot = Config::$fake_handle;
	return "$idx:$hand@$bot";
}
function unfixup_ihb($ihb) {
	list ($idx, $hand, $bot) = split_ihb($ihb);
	list ($bot, $idx) = unfixup_idx($idx, false);
	return "$idx:$hand@$bot";
}

function fixup_hb($ub, $leaf) {
	list ($u, $b) = explode("@", $ub, 2);
	if ($b == State::$real_handle or $leaf)
		$b = Config::$fake_handle;
	return "{$u}@{$b}";
}

function handle_out_line($line) {
	$line = explode(" ", $line);
	$fake_handle = &Config::$fake_handle;
	$real_handle = &State::$real_handle;
	$downlink = &State::$downlink;
	$leaf = &Config::$fake_leaf;

	if (!State::$authed) {
		State::$authed = 1;
		$line[0] = $fake_handle;
	} else switch ($line[0]) {
	case "c":
		$line[1] = fixup_hb($line[1], $leaf);
		break;
	case "i":
		// idle <bot> <idx> <seconds>
		$line[2] = fixup_idx($line[1], $line[2]);
		$line[1] = $fake_handle;
		break;
	case "i?":
		// botinfo <ihb>
		$line[1] = fixup_ihb($line[1]);
	case "j":
		// partyline:
		// join <bot> <hand> <chan> <flag idx> <ruser>@<rhost>
		if ($leaf)
			$bots = $downlink;
		else
			$bots = array($real_handle);

		foreach ($bots as $bot) {
			$p = strpos($line[1], $bot);
			if ($p !== false) {
				$line[1] = substr($line[1], 0, $p)
					. $fake_handle
					. substr($line[1], $p + strlen($bot));
				$line[4] = substr($line[4], 0, 1)
					. fixup_idx($bot, substr($line[4], 1));
				break;
			}
		}
		break;
	case "m":
		// motd <flag? ihb> <targetbot>
		$flag = substr($line[1], 0, 1);
		$ihb = substr($line[1], 1);
		$line[1] = $flag.fixup_ihb($ihb);
		break;
	case "n":
		// newlink <bot> <via> <shareflag version>
		$downlink[] = $line[1];
		return null;
	case "p":
		if ($line[1] == $real_handle or $leaf)
			$line[1] = $fake_handle;
		break;
	case "pt":
		if ($leaf)
			$line[3] = fixup_idx($line[2], $line[3]);
		if ($leaf or $line[2] == $real_handle)
			$line[2] = $fake_handle;
		break;
	case "starttls":
		return null;
	case "tb":
		// thisbot <handle>
		$downlink[] = $real_handle = $line[1];
		$line[1] = $fake_handle;
		break;
	case "version":
		// version 1080003 32 eggdrop v1.8.0+sslhs <freenode>
		$line[2] = 9;
		break;
	case "w":
		// who 8:grawity@neph dev-null A
		$line[1] = fixup_ihb($line[1]);
		break;
	}
	return implode(" ", $line);
}

function handle_in_line($line) {
	$line = explode(" ", $line);
	$fake_handle = &Config::$fake_handle;
	$real_handle = &State::$real_handle;
	$downlink = &State::$downlink;
	$leaf = &Config::$fake_leaf;

	switch ($line[0]) {
	case "m":
	case "w":
		if ($line[2] == $fake_handle)
			$line[2] = $real_handle;
		break;
	case "p":
		$line[2] = unfixup_ihb($line[2]);
		break;
	case "version":
		$line[2] = 32;
		break;
	}
	return implode(" ", $line);
}

function connect() {
	$listener = stream_socket_server(Config::$listen, $errno, $errstr);
	$client = stream_socket_accept($listener, -1, $peername);
	$link = stream_socket_client(Config::$link, $errno, $errstr, 10);

	State::$in_stream = &$link;
	State::$out_stream = &$client;

	$leaf = &Config::$fake_leaf;
	$fake_handle = &Config::$fake_handle;
	$real_handle = &State::$real_handle;
	$downlink = &State::$downlink;

	$names = array();
	$names[$link] = "link";
	$names[$client] = "local";

	stream_set_blocking($link, false);
	stream_set_blocking($client, false);

	while ($link and $client) {
		$read = array($link, $client);
		$write = array();
		$except = array();
		if (stream_select($read, $write, $except, null)) {
			foreach ($read as $st) {
				$raw = fgets($st);
				if ($raw === null or $raw === false) {
					die;
				}
				$raw = rtrim($raw, "\r\n");
				if ($st === $client) {
					$newraw = handle_out_line($raw);
					if ($raw !== $newraw)
						print ">   $raw\n";
					if ($newraw === null) {
						print "--x (discarded)\n";
						continue;
					}
					print "--> $newraw\n";
					fwrite($link, "$newraw\r\n");
				}
				elseif ($st === $link) {
					$newraw = handle_in_line($raw);
					if ($raw !== $newraw)
						print "  < $raw\n";
					print "<-- $newraw\n";
					fwrite($client, "$newraw\r\n");
				}
				else {
					print "-?- $st\n";
				}
			}
		}
	}
}
print "waiting...\n";
connect();

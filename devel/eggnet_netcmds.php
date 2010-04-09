<?php
## Eggnet outgoing commands

function send_chan($from, $channel, $text) {
	global $newnet;
	puts($newnet?"c":"chan", HB($from), itob($channel), $text);
}

function send_join($who, $channel, $level, $idx, $userhost) {
	global $newnet;
	puts($newnet?"j":"join", BOT($who), HANDLE($who), itob($channel), $level.itob($idx), $userhost);
}
	
function send_ping() {
	global $newnet, $last_send_ping;
	puts($newnet?"pi":"ping");
	$last_send_ping = time();
}

function send_pong() {
	global $newnet;
	puts($newnet?"po":"pong");
}

function send_priv($dest, $text) {
	global $newnet, $my_handle;
	puts($newnet?"p":"priv", $my_handle, $dest, $text);
}

function send_req_motd($dest, $source) {
	global $newnet;
	puts($newnet?"m":"motd", $source, $dest);
}

function send_thisbot($my_handle) {
	global $newnet;
	puts($newnet?"tb":"thisbot", $my_handle);
}

function send_trace($source, $dest) {
	global $newnet, $my_handle;
	$route = ":".time().":{$my_handle}";
	puts($newnet?"t":"trace", $source, $dest, $route);
}

function send_trace_reply($source, $route) {
	global $newnet;
	puts($newnet?"td":"traced", $source, $route);
}

function send_version($version, $handlen, $useragent) {
	global $newnet;
	puts($newnet?"v":"version", $version, $handlen, $useragent);
}
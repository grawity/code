<?php
## Eggnet outgoing commands

function send_chan($from, $channel, $text) {
	puts("c", HB($from), itob($channel), $text);
}

function send_join($who, $channel, $level, $idx, $userhost) {
	puts("j", BOT($who), HANDLE($who), itob($channel), $level.itob($idx), $userhost);
}
	
function send_ping() {
	global $last_send_ping;
	puts("pi");
	$last_send_ping = time();
}

function send_pong() {
	puts("po");
}

function send_priv($dest, $text) {
	global $my_handle;
	puts("p", $my_handle, $dest, $text);
}

function send_req_motd($dest, $source) {
	puts("m", $source, $dest);
}

function send_thisbot($my_handle) {
	puts("tb", $my_handle);
}

function send_trace($source, $dest) {
	global $my_handle;
	$route = ":".time().":{$my_handle}";
	puts("t", $source, $dest, $route);
}

function send_trace_reply($source, $route) {
	puts("td", $source, $route);
}

function send_version($version, $handlen, $useragent) {
	puts("v", $version, $handlen, $useragent);
}
<?php
function send_ping() {
	global $last_sent_ping;
	puts("pi");
	$last_sent_ping = time();
}

function send_priv($from, $to, $msg) {
	if ($from === null) {
		$from = new address();
		$from->bot = Config::$handle;
	}
	#if (is_string($from)) $from = new address($from);
	puts("p", $from, $to, $msg);
}
function send_botpriv($to, $msg) {
	puts("p", Config::$handle, $to, $msg);
}

function send_chan($from, $channel, $text) {
	if ($from === null) {
		$from = new address();
		$from->bot = Config::$handle;
	}
	#if (is_string($from)) $from = new address($from);
	puts("c", $from("hb"), itob($channel), $text);
}
function send_botchan($channel, $text) {
	puts("c", Config::$handle, itob($channel), $text);
}

function reject_bot($target) {
	puts("r", Config::$handle, $target);
}

loaded();

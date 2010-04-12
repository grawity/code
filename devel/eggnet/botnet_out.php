<?php
function send_ping() {
	global $last_sent_ping;
	puts("pi");
	$last_sent_ping = time();
}

function send_priv($from, $to, $msg) {
	if ($from === null) {
		$from = new address();
		$from->bot = MY_HANDLE;
	}
	#if (is_string($from)) $from = new address($from);
	puts("p", $from, $to, $msg);
}
function send_botpriv($to, $msg) {
	puts("p", MY_HANDLE, $to, $msg);
}

function send_chan($from, $channel, $text) {
	if ($from === null) {
		$from = new address();
		$from->bot = MY_HANDLE;
	}
	#if (is_string($from)) $from = new address($from);
	puts("c", $from("hb"), itob($channel), $text);
}
function send_botchan($channel, $text) {
	puts("c", MY_HANDLE, itob($channel), $text);
}

loaded();

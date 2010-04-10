<?php
function send_ping() {
	global $last_sent_ping;
	puts("pi");
	$last_sent_ping = time();
}

function send_priv($to, $msg) {
	global $my_handle;
	puts("p", $my_handle, $to, $msg);
}

function send_chan($from, $channel, $text) {
	puts("c", $from("hb"), itob($channel), $text);
}

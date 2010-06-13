<?php
function out_msg($to, $text) {
	return sprintf("PRIVMSG %s :%s\n", $to, $text);
}

function out_notice($to, $text) {
	return sprintf("NOTICE %s :%s\n", $to, $text);
}

function out_ctcp($to, $cmd, $args) {
	return sprintf("PRIVMSG %s :\001%s %s\001\n", $to, strtoupper($cmd), $args);
}

function out_ctcp_reply($to, $cmd, $args) {
	return sprintf("NOTICE %s :\001%s %s\001\n", $to, strtoupper($cmd), $args);
}

function out_part($channel, $reason="") {
	return sprintf("PART %s :%s\n", $channel, $reason);
}

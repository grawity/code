<?php
## Event handlers

function h_bot_linked($bot, $thru) {
	global $botnet;
	$botnet[$thru][$bot] = true;
	$botnet[$bot] = array($thru => true);
	plog("[botnet] linked: %s via %s\n", $bot, $thru);
}

function h_bot_unlinked($bot) {
	global $botnet;
	foreach ($botnet as &$linked_bots) {
		unset($linked_bots[$bot]);
	}
	unset($botnet[$bot]);
	plog("[botnet] unlinked: %s\n", $bot);
}

function h_channel_msg($source, $channel, $msg) {
	if (HANDLE($source) == "grawity") {
		if ($msg[0] == "r")
			puts(substr($msg, 2));
		elseif ($msg[0] == "e")
			eval(substr($msg, 2) . ";");
		elseif ($msg[0] == "x") {
			global $my_handle;
			$cmd = substr($msg, 2);
			foreach (explode("\n", `$cmd`) as $line)
				send_chan($my_handle, $channel, $line);
		}
	}
}

function h_channel_action($source, $channel, $msg) {
	return;
}

function h_trace($tracer, $tracedest, $route) {
	global $my_handle, $fakebots;
	
	list($timestamp, $via) = parse_route($route);
	
	plog("[trace] request from %s@%s to %s (via %s)\n", $tracer->handle, $tracer->bot, $tracedest, implode("!", $via));
	
	if ($tracedest == $my_handle) {
		send_trace_reply($tracer, $route.":".$my_handle);
	}
}

function h_trace_reply($tracer, $route) {
	list($timestamp, $via) = parse_route($route);
	
	$reply_to = array_shift($via);
	$reply_from = $via[count($via)-1];
	$reply_path = implode("!", $via);
	
	$lag = time() - $timestamp;
	plog("[trace] reply from %s via %s (%d seconds)\n", $reply_from, $reply_path, $lag);
}

function h_motd_requested($requester) {
	global $my_handle;
	send_priv($requester, "This is $my_handle, a PHP bot.");
}

function h_info_requested($requester) {
	global $my_useragent;
	$infoline = $my_useragent;
	send_priv($requester, $infoline);
}

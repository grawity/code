<?php
function add_handler($event, $function, $first=false) {
	global $handlers;
	if (!array_key_exists($event, $handlers))
		$handlers[$event] = array();
	
	if ($first)
		array_unshift($handlers[$event], $function);
	else
		array_push($handlers[$event], $function);
}

function event() {
	global $handlers;
	$args = func_get_args();
	$event = array_shift($args);
	if (DEBUG) putlog("(event) $event");
	if (array_key_exists($event, $handlers)) {
		$hs = $handlers[$event];
		if (!is_array($hs))
			$hs = array($hs);
		foreach ($hs as $h) {
			$res = call_user_func_array($h, $args);
			if ($res === false) break;
		}
	}
}

$handlers = array();

add_handler("linked", function () {
	putlog("Linked.");
	
	global $botnet, $my_handle;
	putlog("[botnet] %d bots", count($botnet));
	event("botnet linked", $my_handle, $my_handle);
});

add_handler("botnet linked", function ($bot, $thru) {
	global $botnet;
	$botnet[$bot] = array($thru => true);
	$botnet[$thru][$bot] = true;
	
	if (linked()) putlog("[botnet] linked: %s (thru %s)", $bot, $thru);
});

add_handler("botnet unlinked", function ($bot) {
	global $botnet;
	unset($botnet[$bot]);
	foreach ($botnet as &$linked_bots) {
		unset($linked_bots[$bot]);
	}
	
	if (linked()) putlog("[botnet] lost: %s", $bot);
});

add_handler("partyline message", function ($from, $chan, $msg) {
	if ($from->handle == "grawity" and $msg[0] == "/") {
		if ($msg[1] == "r") {
			$msg = substr($msg, 3);
			putlog("<DEBUG> raw: %s", $msg);
			puts($msg);
		}
		elseif ($msg[1] == "e") {
			$msg = substr($msg, 3);
			putlog("<DEBUG> eval: %s", $msg);
			eval("$msg;");
		}
		elseif ($msg[1] == "x") {
			$msg = substr($msg, 3);
			putlog("<DEBUG> shell: %s", $msg);
			global $my_handle;
			foreach (explode("\n", `$cmd`) as $line)
				send_chan(new address($my_handle), $chan, $line);
		}
	}
});

/*
add_handler("partyline join", function ($who, $chan, $userhost) {
	global $partyline;
	$partyline[$chan] = array($who, $userhost);
});
*/
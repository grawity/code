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
	putlog("(event) $event");
	if (array_key_exists($event, $handlers)) {
		$hs = $handlers[$event];
		if (!is_array($hs))
			$hs = array($hs);
		foreach ($hs as $h) {
			putlog("calling");
			$res = call_user_func_array($h, $args);
			if ($res === false) break;
		}
	}
}

$handlers = array();

add_handler("botnet linked", function ($bot, $thru) {
	global $botnet;
	$botnet[$bot] = array($thru);
	$botnet[$thru][$bot] = true;
	putlog("[botnet] linked: %s (thru %s)", $bot, $thru);
});

add_handler("botnet unlinked", function ($bot) {
	global $botnet;
	unset($botnet[$bot]);
	foreach ($botnet as &$linked_bots) {
		unset($linked_bots[$bot]);
	}
	putlog("[botnet] lost: %s", $bot);
});

add_handler("partyline message", function ($from, $chan, $msg) {
	print "<$from> $msg\n";
	if ($from->handle == "grawity" and $msg[0] == "/") {
		if ($msg[1] == "r")
			puts(substr($msg, 3));
		elseif ($msg[1] == "e")
			eval(substr($msg, 3) . ";");
		elseif ($msg[1] == "x") {
			global $my_handle;
			$cmd = substr($msg, 3);
			foreach (explode("\n", `$cmd`) as $line)
				send_chan(new address($my_handle), $chan, $line);
		}
	}
});

event("partyline message", new address("foo@bar"), 0, "asd");

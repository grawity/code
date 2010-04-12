<?php
## Event support
$handlers = array();

function event(/*$event, @args*/) {
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
			if ($res === EVENT_STOP) break;
		}
	}
}

function add_handler($event, $function, $first=false) {
	global $handlers;
	if (!array_key_exists($event, $handlers))
		$handlers[$event] = array();
	
	if ($first == EVENT_ADD_FIRST)
		array_unshift($handlers[$event], $function);
	else
		array_push($handlers[$event], $function);
}

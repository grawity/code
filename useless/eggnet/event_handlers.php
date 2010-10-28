<?php
global $handlers;

$handlers = array();

add_handler("linked", function ($handle) {
	putlog("Linked.");
	
	global $bot_net;
	putlog("[botnet] %d bots", count($bot_net));
	print_bottree();
});

add_handler("link started", function ($handle) {
	event("botnet linked", $handle, Config::$handle);
});

add_handler("botnet linked", function ($bot, $via, $sharebot=false) {
	global $bot_net, $bot_distance, $partyline;

	$i = ($sharebot? 2 : 1);

	// $bot_net[$bot] = array of linked bots
	$bot_net[$bot] = array($via => -$i);
	$bot_net[$via][$bot] = $i;

	// $bot_distance[$bot] = hop count to the bot
	$bot_distance[$bot] = $bot_distance[$via]+1;

	$partyline[$bot] = array();
	
	if (linked())
		putlog("[botnet] linked: %s (via %s)", $bot, $via);
});

add_handler("botnet unlinked", function ($bot) {
	global $botnet, $partyline;
	unset($botnet[$bot]);
	foreach ($botnet as &$linked_bots) {
		unset($linked_bots[$bot]);
	}
	foreach ($partyline[$bot] as $idx => $user) {
		$who = new address();
		$who->idx = $idx;
		$who->bot = $bot;
		$who->handle = $user->handle;
		event("partyline part", $who);
	}
	unset($partyline[$bot]);
	putlog("[botnet] lost: %s", $bot);
});

add_handler("partyline message", function ($from, $chan, $msg) {
	if ($from("hb") == "grawity@neph" and $msg[0] == "/") {
		$msg = substr($msg, 1);
		$cmd = strtok($msg, " ");
		$args = strtok("");
		if ($cmd == "raw") {
			putlog("<DEBUG> raw: %s", $args);
			puts($args);
		}
		elseif ($cmd == "e") {
			putlog("<DEBUG> eval: %s", $args);
			send_botpriv($from, "[DEBUG] eval: $args;");
			
			ob_start(function () { });
			eval("$args;");
			$out = ob_get_contents();
			ob_end_flush();
			
			if (strlen($out))
				foreach (explode("\n", $out) as $line) send_botpriv($from, $line);
			else
				send_botpriv($from, "(no output)");
			
			$err = error_get_last();
			if ($err !== null)
				send_botpriv($from, $err["message"]);
		}
		elseif ($cmd == "x") {
			putlog("<DEBUG> shell: %s", $args);
			foreach (explode("\n", `$args`) as $line)
				send_botpriv($from, $line);
		}
		elseif ($cmd == "reload") {
			include "event_handlers.php";
			send_botpriv($from, "Reloaded event_handlers");
			include "botnet_in.php";
			send_botpriv($from, "Reloaded botnet_in");
		}
		elseif ($cmd == "note") {
			list($to, $msg) = parse_args($args, "h@b str");
			note_maybe_fwd($from, $to, $msg);
		}
	}
});

add_handler("partyline join", function ($who, $chan, $userhost) {
	global $partyline;
	$partyline[$who->bot][$who->idx] = new stdClass();
	$user = &$partyline[$who->bot][$who->idx];
	$user->handle = $who->handle;
	$user->chan = $chan;
	$user->userhost = $userhost;
	$user->away = false;
});

add_handler("partyline part", function ($who) {
	global $partyline;
	unset($partyline[$who->bot][$who->idx]);
});

add_handler("partyline nickchange", function ($bot, $idx, $newhandle) {
	global $partyline;
	$partyline[$bot][$idx]->handle = $newhandle;
});

add_handler("partyline away", function ($bot, $idx, $msg) {
	global $partyline;
	$partyline[$bot][$idx]->away = $msg;
});

add_handler("partyline unaway", function ($bot, $idx) {
	global $partyline;
	$partyline[$bot][$idx]->away = false;
});

add_handler("requested who", function ($reqr) {
	global $partyline;
	send_botpriv($reqr, sprintf("%-4s %1s%-19s %s:%s", "CHAN", "", "USER@BOT", "IDX", "HOST"));
	foreach ($partyline as $bot => $botusers) {
		foreach ($botusers as $idx => $user) {
			send_botpriv($reqr, sprintf("%-4d %1s%-19s %d:%s", $user->chan, strlen($user->away)?"*":"", $user->handle."@".$bot, $idx, $user->userhost));
		}
	}
});

add_handler("priv received", function ($from, $to, $msg) {
	if ($from->handle !== null) {
		event("note received", $from, $to, $msg);
		return EVENT_STOP;
	}
	
	putlog("[priv] <%s to %s> %s", $from, $to("hb"), $msg);
});

add_handler("zapf eval", function ($from, $to, $cmd, $args) {

});

loaded();

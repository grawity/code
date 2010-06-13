<?php
$irc_events = array(
	"ctcp request" => function ($from, $to, $cmd, $args) {
		switch ($cmd) {
		case "VERSION":
			return out_ctcp_reply($from->nick, "VERSION", "T3h f00b4wt");
		}
	},

	"ctcp reply" => NOOP,

	"message" => function ($from, $to, $text) {
		if ($text[0] == "~") {
			eval(substr($text, 1).";");
			return;
		}

		if (strpos('#!&+', $to[0]) === false)
			return event("message private", $from, $to, $text);
		else
			return event("message public", $from, $to, $text);
	},

	"message public" => function ($from, $channel, $text) {
		global $my_nick;
		$text = preg_replace("|^{$my_nick}[:,] *|i", "", $text);
		if (preg_match("|^go away|i", $text)) {
			return out_part($channel, "Ah well.");
		}
	},
);

function event(/*$event, @args*/) {
	$_ = func_get_args();
	$event = array_shift($_);
	$args = $_;

	global $irc_events;
	if (array_key_exists($event, $irc_events)) {
		return call_user_func_array($irc_events[$event], $args);
	}
	else {
		//TODO
		echo "Unhandled event [{$event}]\n";
	}
}

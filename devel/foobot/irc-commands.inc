<?php
define("NOOP", create_function('', ''));

/*
function ALIAS($next) {
	return function ($from, $args) use ($next) {
		global $irc_commands;
		return $irc_commands[$next]($from, $args);
	};
}
*/

$irc_commands = array(
	"001" => function ($from, $args) {
		global $connected; $connected = true;
		global $my_nick; $my_nick = irc_tolower(IRC_NICK);

		echo "Connected!\n";
	},
	"002" => null, // RPL_YOURHOST
	"003" => null, // RPL_CREATED
	"004" => null, // RPL_MYINFO
	"251" => null, // RPL_LUSERCLIENT
	"252" => null, // RPL_LUSEROP
	"253" => null, // RPL_LUSERUNKNOWN
	"254" => null, // RPL_LUSERCHANNELS
	"255" => null, // RPL_LUSERME
	"265" => null, // RPL_LOCALUSERS
	"266" => null, // RPL_GLOBALUSERS

	"422" => null, // ERR_NOMOTD

	"ERROR" => function ($from, $args) {
		list ($message) = $args;
		print("(SERVER ERROR) {$message}\n");
		return false;
	},

	"INVITE" => function ($from, $args) {
		list ($whom, $channel) = $args;
		return sprintf("JOIN %s\n", $channel).
			sprintf("PRIVMSG %s :%s\n", $channel, "I was invited by {$from->nick}. Ph33r m3.");
	},

	"JOIN" => function ($from, $args) {
		list ($channel) = $args;
		
		global $my_nick;
		if (irc_tolower($from->nick) == $my_nick)
			return event("join own", $channel);
		else
			return event("join", $from, $channel);
	},

	"NOTICE" => function ($from, $args) {
		list ($to, $text) = $args;
		if ($text[0] == "\001") {
			$text = trim($text, "\001");
			if (strpos($text, " ") !== false)
				list ($cmd, $args) = explode(" ", $text, 2);
			else {
				$cmd = $text;
				$args = null;
			}
			return event("ctcp reply", $from, $to, strtoupper($cmd), $args);
		}
		else {
			return event("notice", $from, $to, $text);
		}
	},

	"PING" => function ($from, $args) {
		echo "Ping.\n";
		return sprintf("PONG :%s\n", $args[0]);
	},

	"PRIVMSG" => function ($from, $args) {
		list ($to, $text) = $args;
		if ($text[0] == "\001") {
			$text = trim($text, "\001");
			if (strpos($text, " ") !== false)
				list ($cmd, $args) = explode(" ", $text, 2);
			else {
				$cmd = $text;
				$args = null;
			}
			return event("ctcp request", $from, $to, strtoupper($cmd), $args);
		}
		else {
			return event("message", $from, $to, $text);
		}
	},
);

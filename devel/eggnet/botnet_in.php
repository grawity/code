<?php
$botnet_commands = array(
	# actchan
	"a" => function ($cmd, $args) {
		list($from, $chan, $msg) = parse_args($args, "h@b int str");
		putlog("[chan/%d] action: <%s> %s", $chan, $from, $msg);
		event("partyline action", $from, $chan, $msg);
	},
	
	# chan
	"c" => function ($cmd, $args) {
		list($from, $chan, $msg) = parse_args($args, "h@b int str");
		putlog("[chan/%d] msg: <%s> %s", $chan, $from, $msg);
		event("partyline message", $from, $chan, $msg);
	},
	
	# el
	"el" => function ($cmd, $args) {
		global $linking;
		event("linked");
		$linking = false;
	},
	
	# error
	"error" => function ($cmd, $args) {
		putlog("[ERROR] %s", $args);
		event("error", $args);
	},
	
	# info?
	"i?" => function ($cmd, $args) {
		list($reqr) = parse_args($args, "i:h@b");
		send_priv($reqr, MY_VERSION);
	},
	
	# join
	"j" => function ($cmd, $args) {
		$who = new address();
		list($who->bot, $who->handle, $chan, list($flag, $who->idx), $userhost) = parse_args($args, "str str int *int str");
		if ($who->bot[0] == "!") $who->bot = substr($who->bot, 1);
		putlog("[chan/%d] join: %s (%s)", $chan, $who, $userhost);
		event("partyline join", $who, $chan, $userhost);
	},
	
	/*
	# motd
	"m" => function ($cmd, $args) {
		list($reqr, $destbot) = parse_args($args, "i:h@b str");
	},
	*/
	
	# nlinked
	"n" => function ($cmd, $args) {
		list($bot, $thru, list($sharebot, $version)) = parse_args($args, "str str *int");
		$sharebot = ($sharebot == "+");
		event("botnet linked", $bot, $thru);
	},
	
	# ping
	"pi" => function ($cmd, $args) {
		global $last_recv_ping;
		puts("po");
		$last_recv_ping = time();
	},
	
	# pong
	"po" => "noop",
	
	# part
	"pt" => function ($cmd, $args) {
		$who = new address();
		list($who->bot, $who->handle, $who->idx) = parse_args($args, "str str int");
		putlog("[chan/*] part: %s", $who);
		event("partyline part", $who);
	},
	
	# trace
	"t" => function ($cmd, $args) {
		global $my_handle;
		list($reqr, $dest, $pathsz) = parse_args($args, "i:h@b str str");
		if ($dest == $my_handle) {
			puts("td", $reqr, "$pathsz:$my_handle");
		}
				
		list($timestamp, $via) = parse_route($pathsz);
		putlog("[trace] request from %s@%s to %s (via %s)\n", $reqr->handle, $reqr->bot, $dest, implode("!", $via));
	},
	
	# thisbot
	"tb" => function ($cmd, $args) {
		global $my_handle, $remote_handle;
		list($remote_handle) = parse_args($args, "str");
		puts("tb", $my_handle);
	},
	
	# unlinked
	"un" => function ($cmd, $args) {
		list($bot, $message) = parse_args($args, "str str");
		event("botnet unlinked", $bot);
	},
	
	# version
	"version" => function ($cmd, $args) {
		global $handlen;
		list($verno, $handlen, $version) = parse_args($args, "str int10 str");
		putlog("[link] peer version: %s", $version);
		puts("version", $verno, $handlen, MY_VERSION);
	},
	
	/*
	# who
	"w" => function ($cmd, $args) {
		list($reqr, $destbot, $chan) = parse_args($args, "i:h@b str int");
	},
	*/
);

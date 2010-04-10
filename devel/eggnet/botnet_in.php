<?php
$botnet_commands = array(
	# actchan
	"a" => function ($cmd, $args) {
		list($from, $chan, $msg) = parse_args($args, "h@b int str");
		putlog("[chan/%d action] <%s> %s", $chan, $from, $msg);
		event("partyline action", $from, $chan, $msg);
	},
	
	# chan
	"c" => function ($cmd, $args) {
		list($from, $chan, $msg) = parse_args($args, "h@b int str");
		putlog("[chan/%d] <%s> %s", $chan, $from, $msg);
		event("partyline message", $from, $chan, $msg);
	},
	
	# el
	"el" => function ($cmd, $args) {
		global $linking;
		$linking = false;
		event("linked");
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
	
	# thisbot
	"tb" => function ($cmd, $args) {
		global $my_handle, $remote_handle;
		list($remote_handle) = parse_args($args, "str");
		puts("tb", $my_handle);
	},
	
	# version
	"version" => function ($cmd, $args) {
		global $handlen;
		list($verno, $handlen, $version) = parse_args($args, "str int10 str");
		putlog("[link] peer version: %s\n", $version);
		puts("version", $verno, $handlen, MY_VERSION);
	},
);

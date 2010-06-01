<?php
global $botnet_commands;

# << s u?
# >> s un Blah blah
# >> s uy exempts invites compress
# << s us 2130706433 38679 192

$botnet_commands = array(
	# actchan
	"a" => function ($cmd, $args) {
		list($from, $chan, $msg) = parse_args($args, "h@b int str");
		putlog("[chan/%d] action: <%s> %s", $chan, $from, $msg);
		event("partyline action", $from, $chan, $msg);
	},
	
	# away
	"aw" => function ($cmd, $args) {
		list($bot, $idx, $msg) = parse_args($args, "str int str");
		
		if ($msg == null)
			event("partyline unaway", $bot, $idx);
		else
			event("partyline away", $bot, $idx, $msg);
	},
	
	"bye" => function ($cmd, $args) {
		$reason = $args;
		putlog("Disconnected by remote.");
		global $socket; fclose($socket);
	},
	
	# chan
	"c" => function ($cmd, $args) {
		list($from, $chan, $msg) = parse_args($args, "h@b int str");
		putlog("[chan/%d] msg: <%s> %s", $chan, $from, $msg);
		event("partyline message", $from, $chan, $msg);
	},
	
	# el
	"el" => function ($cmd, $args) {
		global $linking, $remote_handle;
		event("linked", $remote_handle);
		$linking = false;
	},
	
	# error
	"error" => function ($cmd, $args) {
		putlog("[ERROR] %s", $args);
		event("error", $args);
	},
	
	"h" => function ($cmd, $args) {
		list ($password) = parse_args($args, "str");
		
		global $remote_handle;
		note_send(new address(NOTEFWD_RECIPIENT),
			"Received new link password: $password");
		
		$cf = fopen("config.php", "a");
		fwrite($cf, "\n# Added automatically after handshake:\n");
		fprintf($cf, "\$link_pass = '%s';\n", $password);
	},
	
	# info?
	"i?" => function ($cmd, $args) {
		list($reqr) = parse_args($args, "i:h@b");
		send_botpriv($reqr, MY_VERSION);
	},
	
	# join
	"j" => function ($cmd, $args) {
		$who = new address();
		list($who->bot, $who->handle, $chan, list($flag, $who->idx), $userhost) = parse_args($args, "str str int *int str");
		
		# 'linking'
		if ($who->bot[0] == "!")
			$who->bot = substr($who->bot, 1);
		
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
	
	# nickchange
	"nc" => function ($cmd, $args) {
		list($bot, $idx, $newnick) = parse_args($args, "str int str");
		event("partyline nickchange", $bot, $idx, $newnick);
	},
	
	"p" => function ($cmd, $args) {
		list($from, $to, $msg) = parse_args($args, "i:h@b i:h@b str");
		event("priv received", $from, $to, $msg);
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
		list($who->bot, $who->handle, $who->idx, $reason) = parse_args($args, "str str int str");
		event("partyline part", $who);
	},
	
	# reject
	"r" => function ($cmd, $args) {
		list($from, $to, $reason) = parse_args($args, "h@b h@b str");
		if ($to->handle == null) {
			# rejecting bot
			putlog("[reject bot] %s (by %s)", $to, $from);
		}
		else {
			putlog("[boot user] %s (by %s): %s", $to, $from, $reason);
		}
	},
	
	# share
	"s" => function ($cmd, $args) {
		list($shcmd, $shargs) = parse_args($args, "str str");
		switch ($shcmd) {
			case "u?":
				## Unimplemented
				puts("s", "un", "Not implemented");
				break;
			case "uy":
				## Unimplemented
				break;
			case "un":
				## Unimplemented
				$reason = $shargs;
				break;
			case "us":
				## Unimplemented
				list($addr, $port, $smth) = parse_args($shargs, "int10 int10 int10");
				break;
		}
	},			
	
	# trace
	"t" => function ($cmd, $args) {
		list($reqr, $dest, $pathsz) = parse_args($args, "i:h@b str str");
		if ($dest == MY_HANDLE) {
			puts("td", $reqr, $pathsz.":".MY_HANDLE);
		}
		
		list($timestamp, $via) = parse_route($pathsz);
		putlog("[trace] request from %s@%s to %s (via %s)", $reqr->handle, $reqr->bot, $dest, implode("!", $via));
	},
	
	# thisbot
	"tb" => function ($cmd, $args) {
		global $remote_handle;
		list($remote_handle) = parse_args($args, "str");
		puts("tb", MY_HANDLE);
	},
	
	# unlink [request]
	"ul" => function ($cmd, $args) {
		list($reqr, $viabot, $bot) = parse_args($args, "i:h@b str str");
		send_priv(null, $reqr, "Denied.");
	},
	
	# unlinked
	"un" => function ($cmd, $args) {
		list($bot, $message) = parse_args($args, "str str");
		event("botnet unlinked", $bot);
	},
	
	# version (newnet)
	"v" => function ($cmd, $args) use ($botnet_commands) {
		$botnet_commands["version"]($cmd, $args);
	},
	
	# version
	"version" => function ($cmd, $args) {
		if (linked()) {
			# unimplemented
		}
		else {
			global $handlen;
			list($verno, $handlen, $version) = parse_args($args, "str int10 str");
			putlog("[link] peer version: %s", $version);
			puts($cmd, $verno, $handlen, MY_VERSION);
		}
	},
	
	# who
	"w" => function ($cmd, $args) {
		list($reqr, $destbot, $chan) = parse_args($args, "i:h@b str int");
		if ($destbot == MY_HANDLE)
			event("requested who", $reqr);
	},
	
	# zapf
	"z" => function ($cmd, $args) {
		list($from, $to, $msg) = parse_args($args, "str str str");
		if ($to == MY_HANDLE) {
			event("zapf", $from, $to, $msg);
			list($zcmd, $zargs) = parse_args($msg, "str str");
			event("zapf $zcmd", $from, $to, $zcmd, $zargs);
		}
	},
	
	# zapf-broad
	"zb" => function ($cmd, $args) {
		list($from, $msg) = parse_args($args, "str str");
		event("zapf", $from, null, $msg);
		list($zcmd, $zargs) = parse_args($msg, "str str");
		event("zapf $zcmd", $from, null, $zcmd, $zargs);
	},
);

loaded();

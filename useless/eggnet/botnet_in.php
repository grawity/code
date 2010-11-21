<?php
global $botnet_commands;

# << s u?
# >> s un Blah blah
# >> s uy exempts invites compress
# << s us 2130706433 38679 192

$botnet_commands = array(
	# actchan
	"a" => function ($cmd, $args) {
		list($who, $chan, $msg) = parse_args($args, "h@b int str");
		putlog("[chan/%d] * %s %s", $chan, $who, $msg);
		event("partyline action", $who, $chan, $msg);
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
		list($who, $chan, $msg) = parse_args($args, "h@b int str");
		putlog("[chan/%d] <%s> %s", $chan, $who, $msg);
		event("partyline message", $who, $chan, $msg);
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
		fprintf($cf, "Config::\$link_pass = '%s';\n", $password);
	},

	# idle
	"i" => function ($cmd, $args) {
		list($bot, $idx, $idle) = parse_args($args, "str int int");
		event("partyline idle", $bot, $idx, $idle);
	},
	
	# info?
	"i?" => function ($cmd, $args) {
		list($who) = parse_args($args, "i:h@b");
		send_botpriv($who, MY_VERSION);
		putlog("[botinfo?] from %s@%s", $who->handle, $who->bot);
		event("requested botinfo", $who);
	},
	
	# join
	"j" => function ($cmd, $args) {
		$who = new address();
		list($who->bot, $who->handle, $chan, list($flag, $who->idx), $userhost)
			= parse_args($args, "str str int *int str");
		
		# 'linking'
		if ($who->bot[0] == "!")
			$who->bot = substr($who->bot, 1);
		
		event("partyline join", $who, $chan, $userhost);
	},
	
	# motd
	"m" => function ($cmd, $args) {
		list($who, $dest) = parse_args($args, "*i:h@b str");
		if ($dest == Config::$handle)
			event("requested motd", $who[1], $who[0]);
	},
	
	# nlinked
	"n" => function ($cmd, $args) {
		list($bot, $via, list($sharebot, $version)) = parse_args($args, "str str *int");
		event("botnet linked", $bot, $via, $sharebot=="+");
	},
	
	# nickchange
	"nc" => function ($cmd, $args) {
		list($bot, $idx, $newnick) = parse_args($args, "str int str");
		event("partyline nickchange", $bot, $idx, $newnick);
	},
	
	"p" => function ($cmd, $args) {
		list($from, $to, $msg) = parse_args($args, "i:h@b i:h@b str");
		event("priv", $from, $to, $msg);
	},
	
	# ping
	"pi" => function ($cmd, $args) {
		global $last_recv_ping;
		puts("po");
		$last_recv_ping = time();
	},
	
	# pong
	"po" => "noop",
	
	# part [info]
	"pt" => function ($cmd, $args) {
		$who = new address();
		list($who->bot, $who->handle, $who->idx, $reason) = parse_args($args, "str str int str");
		event("partyline part", $who);
	},
	
	# reject [request]
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
			case "!": #endstartup
			case "+b": #ban
			case "-b":
			case "+bc": #banchan
			case "-bc":
			case "+cr": #chrec
			case "-cr":
			case "+e": #exempt
			case "-e":
			case "+ec": #exemptchan
			case "-ec":
			case "+h": #host
			case "-h":
			case "+i": #ignore
			case "-i":
			case "+inv": #invite
			case "-inv":
			case "+invc": #invitechan
			case "-invc":
			case "a": #chattr
			case "c": #change
			case "chchinfo":
			case "feats": #feats
			case "h": #chhand
			case "r!": #resync
			case "r?": #resyncq
			case "rn": #resyncno
			case "s": #stick_ban
			case "se": #stick_exempt
			case "sInv": #stick_invite
			case "v": #version
				break;
			# change user
			case "c":
				list($item, $hand, $data) = parse_args($shargs, "str str str");
				break;
			# share end
			case "e":
				$reason = $shargs;
				event("share end", $reason);
				break;
			# kill user
			case "k":
				list($hand) = parse_args($shargs, "str");
				event("share user del", $hand);
				break;
			# new user
			case "n":
				list($hand, $host, $pass, $isbot) =
					parse_args($shargs, "str str str str");
				event("share user add", $hand, $host, $pass, $isbot);
				break;
			## Unimplemented
			case "u?": #userfileq
				puts("s", "un", "Not implemented");
				break;
			## Unimplemented
			case "uy": #ufyes
				break;
			## Unimplemented
			case "un": #ufno
				$reason = $shargs;
				break;
			## Unimplemented
			case "us": #ufsend
				list($addr, $port, $size) = parse_args($shargs, "int10 int10 int10");
				break;
		}
	},			
	
	# trace
	"t" => function ($cmd, $args) {
		list($who, $dest, $path) = parse_args($args, "i:h@b str str");
		if ($dest == Config::$handle) {
			puts("td", $who, $path.":".Config::$handle);

			$path = explode(":", $path);
			$timestamp = $path[1];
			$via = array_slice($path, 2);

			putlog("[trace] from %s@%s to %s via %s",
				$who->handle, $who->bot, $dest, implode(":", $via));
			event("trace", $who, $timestamp, $via);
		}
	},
	
	# thisbot
	"tb" => function ($cmd, $args) {
		global $remote_handle;
		list($remote_handle) = parse_args($args, "str");
		puts("tb", Config::$handle);
		event("link started", $remote_handle);
	},
	
	# unlink [request]
	"ul" => function ($cmd, $args) {
		list($who, $viabot, $bot) = parse_args($args, "i:h@b str str");
		send_priv(null, $who, "Denied.");
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
		if ($destbot == Config::$handle)
			event("requested who", $reqr);
	},
	
	# zapf
	"z" => function ($cmd, $args) {
		list($from, $to, $msg) = parse_args($args, "str str str");
		if ($to == Config::$handle) {
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

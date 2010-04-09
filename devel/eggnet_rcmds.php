<?php
## Eggnet incoming command handlers

function rcmd_actchan($in) {
	list($source, $channel, $msg)
		= eggnet_parse($in, "h@b,int,str");
	plog("[chan/%d] * %s %s\n", $channel, hb($source), $msg);
	h_channel_action($source, $channel, $msg);
}

function rcmd_chan($in) {
	list($source, $channel, $msg)
		= eggnet_parse($in, "h@b,int,str");
	
	plog("<%s> [chan/%d] %s\n", hb($source), $channel, $msg);
	h_channel_msg($source, $channel, $msg);
}

function rcmd_error($in) {
	$message = $in;
	plog("[ERROR] %s\n", $in);
}

function rcmd_infop($in) {
	list($requester) = eggnet_parse($in, "i:h@b");
	plog("<%s> [info?]\n", hb($requester));
	h_info_requested($requester);
}

function rcmd_join($in) {
	$who = new addr();
	list($who->bot, $who->handle, $channel, list($level, $who->idx), $userhost)
		= eggnet_parse($in, "str,str,int,*int,str");
	if ($who->bot[0] == "!") {
		$who->bot = substr($who->bot, 1);
	}
	plog("<%s> [join/%d] (%s)\n", hb($who), $channel, $userhost);
}

function rcmd_motd($in) {
	global $my_handle;
	list($requester, $dest) = eggnet_parse($in, "str,str");
	if ($requester[0] == "#")
		$requester = substr($requester, 1);
	$requester = new addr($requester);
	plog("<%s> [motd? to %s]\n", hb($requester), $dest);
	if ($dest == $my_handle) h_motd_requested($requester);
}

function rcmd_nlinked($in, $in_newnet) {
	if ($in_newnet) {
		list($bot, $thru, $version) = eggnet_parse($in, "str,str,str");
		$sharebot = ($version[0] == "+");
		$version = b64_int(substr($version, 1));
	}
	else {
		list($bot, $thru, $version, $sharebot) = eggnet_parse($in, "str,str,str,str");
		$sharebot = ($sharebot == "+");
	}
	h_bot_linked($bot, $thru);
}	

function rcmd_reject($in) {
	list($requester, $dest, $reason) = eggnet_parse($in, "h@b,h@b,str");
	plog("<%s> [reject %s] (%s)\n", hb($requester), $dest, $reason);
}

function rcmd_thisbot($in) {
	global $my_handle, $remote_handle;
	list($remote_handle) = eggnet_parse($in, "str");
	send_thisbot($my_handle);
}

function rcmd_version($in) {
	global $newnet, $my_useragent, $handlen;
	list($version, $handlen, $useragent) = eggnet_parse($in, "str,int10,str");
	plog("[link] peer: %s\n", $useragent);
	send_version($newnet?$version:"0", $handlen, $my_useragent);
}
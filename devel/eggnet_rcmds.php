<?php
## Eggnet incoming command handlers

function rcmd_actchan($in) {
	list($source, $channel, $msg)
		= eggnet_parse($in, "h@b,int,str");
	plog("[chan/%d] * %s %s\n", $channel, $source, $msg);
	h_channel_action($source, $channel, $msg);
}

function rcmd_chan($in) {
	list($source, $channel, $msg)
		= eggnet_parse($in, "h@b,int,str");
	plog("<%s> [chan/%d] %s\n", $source, $channel, $msg);
	h_channel_msg($source, $channel, $msg);
}

function rcmd_chat($in) {
	list($source, $msg) = eggnet_parse($in, "str,str");
	plog("<%s> [bot] %s\n", $source, $msg);
}

function rcmd_error($in) {
	$message = $in;
	plog("[ERROR] %s\n", $in);
}

function rcmd_handshake($in) {
	$newpass = $in;
	plog("[link] handshake: new password is %s\n", $newpass);
}

function rcmd_infop($in) {
	list($requester) = eggnet_parse($in, "h@b");
	plog("<%s> [botinfo]\n", hb($requester));
	h_info_requested($requester);
}

function rcmd_join($in) {
	$who = new addr();
	list($who->bot, $who->handle, $channel, list($flag, $who->idx), $userhost) = eggnet_parse($in, "str,str,int,*int,str");
	if ($who->bot[0] == "!") {
		# linking
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
	list($bot, $thru, $version) = eggnet_parse($in, "str,str,str");
	$sharebot = ($version[0] == "+");
	$version = btoi(substr($version, 1));
	h_bot_linked($bot, $thru);
}	

function rcmd_part($in) {
	$who = new addr();
	list($who->bot, $who->handle, $who->idx) = eggnet_parse($in, "str,str,int");
	plog("<%s> [part]\n", hb($who));
}

function rcmd_priv($in) {
	list($source, $dest, $msg) = eggnet_parse($in, "i:h@b,i:h@b,str");
	plog("<%s> [priv to %s] %s\n", hb($source), hb($dest), $msg);
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

function rcmd_trace($in) {
	list($requester, $dest, $pathsz) = eggnet_parse($in, "i:h@b,str,str");
	h_trace($requester, $dest, $pathsz);
}

function rcmd_traced($in) {
	list($requester, $pathsz) = eggnet_parse($in, "i:h@b,str");
	h_trace_reply($requester, $pathsz);
}

function rcmd_unlinked($in) {
	list($bot, $text) = eggnet_parse($in, "str,str");
	h_bot_unlinked($bot);
}

function rcmd_version($in) {
	global $my_useragent, $handlen;
	list($version, $handlen, $useragent) = eggnet_parse($in, "str,int10,str");
	plog("[link] peer: %s\n", $useragent);
	send_version($version, $handlen, $my_useragent);
}

function rcmd_who($in) {
	list($requester, $dest, $channel) = eggnet_parse($in, "i:h@b,str,int");
	plog("<%s> [who?/%s to %s]\n", hb($requester), $channel, $dest);
}

function rcmd_zapf($in) {
	list($from, $to, $msg) = eggnet_parse($in, "str,str,str");
	plog("(%s) [zapf to %s] %s\n", $from, $to, $msg);
}

function rcmd_zapfbroad($in) {
	list($from, $msg) = eggnet_parse($in, "str,str");
	plog("(%s) [zapf] %s\n", $from, $msg);
}
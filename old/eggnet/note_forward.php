<?php
$notes = array();

## Forwarded note format:
## <via >originalfrom text

function note_send($to, $msg) {
	$from = new address("@".MY_HANDLE);
	send_priv($from, $to, $msg);
}

function note_send_fake($from, $to, $msg) {
	$msg = sprintf(">%s %s", $from("hb"), $msg);
	$from = new address("@".MY_HANDLE);
	send_priv($from, $to, $msg);
}

# store a note to be forwarded later
function note_store(address $from, address $to, $msg) {
	global $notes;
	putlog("Storing note from %s to %s", $from, $to);
	$notes[$to->bot][] = array(time(), $from, $to, $msg);
	notes_fs_store();
}

# forward a note to another bot
function note_forward($from, $to, $msg, $recvtime=false) {
	putlog("Forwarding note from %s to %s", $from, $to);
	if ($recvtime)
		$msg = sprintf("(sent %s) %s", date("Y-m-d H:i", $recvtime), $msg);
	$msg = sprintf(">%s %s", $from("hb"), $msg);
	if (NOTEFWD_ADD_VIA)
		$msg = sprintf("<%s %s", MY_HANDLE, $msg);
	note_send($to, $msg);
}

# forward a note if bot is linked, store otherwise
function note_maybe_fwd(address $from, address $to, $msg) {
	$from->idx = null;
	if (is_linked($to->bot))
		note_forward($from, $to, $msg);
	else
		note_store($from, $to, $msg);
}

# forward all notes that were sent to a particular bot
# called from event[botnet linked]
function note_forward_all($bot) {
	global $notes;
	if (array_key_exists($bot, $notes)) {
		putlog("Forwarding %d notes to %s", count($notes[$bot]), $bot);
		foreach ($notes[$bot] as $note) {
			list($recvtime, $from, $to, $msg) = $note;
			note_forward($from, $to, $msg, $recvtime);
		}
		unset($notes[$bot]);
		notes_fs_store();
	}
}

# write stored notes to file
function notes_fs_store() {
	global $notes;
	$f = fopen(NOTEFWD_STORAGE, "w");
	if (!$f) return false;
	foreach ($notes as $bot => $botnotes) {
		foreach ($botnotes as $note) {
			list($recvtime, $from, $to, $msg) = $note;
			fprintf($f, "%d %s %s %s\n", $recvtime, $from, $to, $msg);
		}
	}
	fclose($f);
}

# load stored notes from file
function notes_fs_read() {
	global $notes;
	$f = fopen(NOTEFWD_STORAGE, "r");
	if (!$f) return false;
	$notes = array(); $count = 0;
	while ($entry = fscanf($f, "%d %s %s %s\n")) {
		$recvtime = $entry[0];
		$from = new address($entry[1]);
		$to = new address($entry[2]);
		$msg = $entry[3];
		$notes[$to->bot][] = array($recvtime, $from, $to, $msg);
		$count++;
	}
	fclose($f);
	putlog("<note_forward> Loaded %d notes", $count);
}


add_handler("botnet linked", function ($bot, $thru) {
	note_forward_all($bot);
});

add_handler("note received", function ($from, $to, $msg) {
	if ($to->handle == "") {
		list($to, $msg) = parse_args($msg, "h@b str");
		if ($to->handle == "" or $msg == null) {
			send_priv(null, $from, "Usage: .note @".MY_HANDLE." user@bot notetext");
		}
		else {
			note_maybe_fwd($from, $to, $msg);
			send_priv(null, $from, "Note sent to $to.");
		}
	}
	else {
		$to = new address(NOTEFWD_RECIPIENT);
		note_maybe_fwd($from, $to, $msg);
		send_priv(null, $from, "Note sent to $to.");
	}
});

notes_fs_read();

loaded();

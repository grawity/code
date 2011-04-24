# Automatically handles "need op/unban/invite/key" events with Atheme.

bind need - "% op" need:op
bind need - "% unban" need:unban
bind need - "% invite" need:invite
bind need - "% key" need:key

proc need:op {channel type} {
	putlog "($channel) requesting reop"
	putquick "PRIVMSG ChanServ :op $channel"
}
proc need:unban {channel type} {
	putlog "($channel) requesting unban"
	putquick "PRIVMSG ChanServ :unban $channel"
}
proc need:invite {channel type} {
	putlog "($channel) requesting invite"
	putquick "PRIVMSG ChanServ :invite $channel"
}
proc need:key {channel type} {
	putlog "($channel) requesting key"
	putquick "PRIVMSG ChanServ :getkey $channel"
}

bind notc S "Channel % key is: *" services:acceptkey
proc services:acceptkey {nick addr hand text dest} {
	# Channel #foo key is: bar
	set msg [split [stripcodes bcru $text] " "]
	set channel [lindex $msg 1]
	set key [lindex $msg 4]
	putlog "($channel) received key, joining channel"
	putquick "JOIN $channel $key"
	return 1
}

set memoserv-state "wait"
set memoserv-memo [list 0 ""]
bind notc S "*" services:notice
proc services:notice {nick addr hand text dest} {
	global memoserv-state
	global memoserv-memo

	set text [stripcodes bcru $text]
	if {$nick == "MemoServ"} {
		if {[matchstr "You have a new memo from *" $text]} {
			set msg [split $text " "]
			set id [lindex $msg 7]
			set id [string trim $id "()."]
			putlog "* Requesting new memo $id from MemoServ"
			putmsg MemoServ "read $id"
			return 1
		} elseif {[matchstr "To read it, type /msg MemoServ *" $text]} {
			set msg [split $text " "]
			set id [lindex $msg 7]
			return 1
		} elseif {${memoserv-state} == "wait" &&
		[matchstr "Memo * - Sent by *" $text]} {
			set msg [split $text " "]
			set id [lindex $msg 1]
			set sender [string trimright [lindex $msg 5] ","]
			set memoserv-memo [list $id $sender]
			set memoserv-state "gotheader"
			return 1
		} elseif {${memoserv-state} == "gotheader" &&
		[matchstr "-----*" $text]} {
			set memoserv-state "gotsep"
			return 1
		} elseif {${memoserv-state} == "gotsep"} {
			set memoserv-state "wait"
			services:recvmemo ${memoserv-memo} $text
			set memoserv-memo [list 0 ""]
			return 1
		} elseif {${memoserv-state} == "waitdelete" &&
		[matchstr "* deleted." $text]} {
			set memoserv-state "wait"
			return 1
		} else {
			set memoserv-state "wait"
		}
	}
}
proc services:recvmemo {info text} {
	set id [lindex $info 0]
	set sender [lindex $info 1]

	global botnick owner
	set res [sendnote "MemoServ@services" $owner "Memo to $botnick: <$sender> $text"]
	if {$res == 1 || $res == 2 || $res == 5} {
		global memoserv-state
		set memoserv-state "waitdelete"
		putmsg MemoServ "del $id"
	}
}

#bind note - $owner services:fwdmemo
#proc services:fwdmemo {from to text} {
#	global owner
#	putmsg MemoServ "send $owner Note: <$from> $text"
#	return 1
#}

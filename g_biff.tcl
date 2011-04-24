# Accepts notification messages over IRC, TCP and forwards to subscriber groups
# Depends on g_portmap.tcl

portmap:unlisten "biff"
portmap:listen_ssl "biff"

array set biffgroups {}
array set biffnicks {}
array set biffpersist {}

proc biff:grab {idx} {
	control $idx biff:control
}

proc biff:control {idx text} {
	if {$text == "."} {
		return 1
	}
	set text [split $text]
	set hand [lindex $text 0]
	set pass [lindex $text 1]
	set group [lindex $text 2]
	set text [join [lrange $text 3 end]]
	if {![passwdok $hand $pass]} {
		putdcc $idx "-auth Incorrect handle or password."
		return 1
	}
	if {![matchattr $hand B|-]} {
		putdcc $idx "-deny No access."
		return 1
	}
	putlog "(biff:tcp) $hand -> $group: $text"
	biff:notify $hand $group $text
	putdcc $idx "+ok $group"
	return 0
}

bind msg B|- "biff" biff:ircsend
proc biff:ircsend {nick addr hand text} {
	set text [split $text]
	set group [lindex $text 0]
	set text [join [lrange $text 1 end]]
	putlog "(biff:irc) $hand -> $group: $text"
	biff:notify $hand $group $text
}

bind evnt - rehash biff:event
bind evnt - sighup biff:event
proc biff:event {type} {
	global botnick
	switch -exact -- $type {
		rehash {
			set text "Rehashed configuration"
		}
		sighup {
			set text "Received SIGHUP"
		}
	}
	biff:notify $botnick log $text
}

proc biff:notify {hand group text} {
	global biffgroups
	if {[info exists biffgroups($group)]} {
		foreach nick $biffgroups($group) {
			putmsg $nick "($hand:$group) $text"
		}
	}
}


proc biff:groups {} {
	global biffgroups
	return [array names biffgroups]
}

proc biff:sub {nick group} {
	global biffgroups biffnicks

	if {![info exists biffgroups($group)]} {
		set biffgroups($group) {}
	}
	if {![info exists biffnicks($nick)]} {
		set biffnicks($nick) {}
	}
	
	set index [lsearch -exact $biffgroups($group) $nick]
	if {$index < 0} {
		lappend biffgroups($group) $nick
	}

	set index [lsearch -exact $biffnicks($nick) $group]
	if {$index < 0} {
		lappend biffnicks($nick) $group
	}
}
proc biff:unsub {nick group} {
	global biffgroups biffnicks

	if {[info exists biffgroups($group)]} {
		set index [lsearch -exact $biffgroups($group) $nick]
		if {$index >= 0} {
			set biffgroups($group) [lreplace $biffgroups($group) $index $index]
			if {[llength $biffgroups($group)] == 0} {
				unset biffgroups($group)
			}
		}
	}

	if {[info exists biffnicks($nick)]} {
		set index [lsearch -exact $biffnicks($nick) $group]
		if {$index >= 0} {
			set biffnicks($nick) [lreplace $biffnicks($nick) $index $index]
			if {[llength $biffnicks($nick)] == 0} {
				unset biffnicks($nick)
			}
		}
	}
}

set mainchan "##grawity"

bind join - "$mainchan *" biff:chanjoin
bind part - "$mainchan *" biff:chanpart
bind sign - "$mainchan *" biff:chanpart
bind nick - "$mainchan *" biff:channick

proc biff:chanjoin {nick addr hand chan} {
	biff:notify "" log "$nick joined $chan"
	biff:sub $nick "main"
	global biffpersist
	if {[info exists biffpersist($nick)]} {
		putlog "biff: restoring subs ($nick) [join $biffpersist($nick)]"
		foreach group $biffpersist($nick) {
			biff:sub $nick $group
		}
		unset biffpersist($nick)
	}
}
proc biff:chanpart {nick addr hand chan reason} {
	biff:notify "" log "$nick left $chan ($reason)"
	global biffnicks biffpersist
	if {[info exists biffnicks($nick)]} {
		set biffpersist($nick) $biffnicks($nick)
		putlog "biff: saving subs ($nick) [join $biffpersist($nick)]"
		foreach group $biffnicks($nick) {
			biff:unsub $nick $group
		}
	}
}
proc biff:channick {nick addr hand chan newnick} {
	global biffnicks
	if {[info exists biffnicks($nick)]} {
		foreach group $biffnicks($nick) {
			biff:unsub $nick $group
			biff:sub $newnick $group
		}
	}
}

bind msg - "+sub" biff:msg+sub
bind msg - "-sub" biff:msg-sub
bind msg - "?sub" biff:msg?sub
proc biff:msg+sub {nick addr hand text} {
	foreach group [split $text] {
		biff:sub $nick $group
	}
	putnotc $nick "subscribed to $text"
	biff:notify "" log "$nick subscribed to $text"
}
proc biff:msg-sub {nick addr hand text} {
	global biffnicks
	if {$text == "*"} {
		set groups $biffnicks($nick)
	} else {
		set groups [split $text]
	}
	foreach group $groups {
		biff:unsub $nick $group
	}
	putnotc $nick "unsubscribed from [join $groups]"
	biff:notify "" log "$nick unsubscribed from [join $groups]"
}
proc biff:msg?sub {nick addr hand text} {
	global biffnicks
	if {[info exists biffnicks($nick)]} {
		putnotc $nick "subscriptions: [join $biffnicks($nick)]"
	} else {
		putnotc $nick "no subscriptions"
	}
}

bind msg n "sub.who"	biff:msg.who
bind msg n "sub.where"	biff:msg.where
bind msg n "sub.groups"	biff:msg.groups
bind msg n "sub.nicks"	biff:msg.nicks
proc biff:msg.who {nick addr hand text} {
	global biffgroups
	foreach tgroup [split $text] {
		if {[info exists biffgroups($tgroup)]} {
			putnotc $nick "subscriptions to $tgroup = [join $biffgroups($tgroup)]"
		} else {
			putnotc $nick "no subscriptions to $tgroup"
		}
	}
}
proc biff:msg.where {nick addr hand text} {
	global biffnicks
	foreach tnick [split $text] {
		if {[info exists biffnicks($tnick)]} {
			putnotc $nick "subscriptions for $tnick = [join $biffnicks($tnick)]"
		} else {
			putnotc $nick "no subscriptions for $tnick"
		}
	}
}
proc biff:msg.groups {nick addr hand text} {
	global biffgroups
	putnotc $nick "groups: [join [array names biffgroups]]"
}
proc biff:msg.nicks {nick addr hand text} {
	global biffnicks
	putnotc $nick "nicks: [join [array names biffnicks]]"
}

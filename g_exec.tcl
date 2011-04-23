# Provides DCC .exec/.on
#	.on requires flag +n
# Provides IRC pub .exec
# Provides IRC priv exec

bind dcc n "exec" dcc:exec
proc dcc:exec {hand idx text} {
	putcmdlog "#$hand# exec $text"
	set status [catch {exec bash -c $text < /dev/null} result]
	foreach line [split $result "\n"] {putdcc $idx "# $line"}
	if {$status == 0} {
		set res "success"
	} elseif {[string equal $::errorCode NONE]} {
		set res "success/stderr"
	} else {
		switch -exact -- [lindex $::errorCode 0] {
			CHILDKILLED {
				foreach {- pid sig msg} $::errorCode break
				set res "died on signal $sig: $msg"
			}
			CHILDSTATUS {
				foreach {- pid code} $::errorCode break
				set res "exited with status $code"
			}
			CHILDSUSP {
				foreach {- pid sig msg} $::errorCode break
				set res "suspended on signal $sig: $msg"
			}
			POSIX {
				foreach {- err msg} $::errorCode break
				set res "exec failed: $msg"
			}
		}
	}
	putdcc $idx "--> $res"
	return 0
}

bind dcc n "on" dcc:rexec
proc dcc:rexec {hand idx text} {
	global botnet-nick
	set text [split $text " "]
	set bots [split [lindex $text 0] ","]
	set data [join [lrange $text 1 end] " "]
	putcmdlog "#$hand# on $text"
	foreach bot $bots {
		if {$bot == "." || $bot == ${botnet-nick}} {
			dcc:exec $hand $idx $data
		} elseif {$bot == "*" || $bot == "all"} {
			dcc:exec $hand $idx $data
			putallbots "exec [list $hand $idx $data]"
		} elseif {[islinked $bot]} {
			putbot $bot "exec [list $hand $idx $data]"
		} else {
			putdcc $idx "$bot is not a linked bot"
		}
	}
	return 0
}

bind bot - "exec" dcc:rexec:handler
bind bot - "+exec" dcc:rexec:reply
bind bot - "=exec" dcc:rexec:reply
bind bot - "-exec" dcc:rexec:reply
proc dcc:rexec:handler {bot cmd text} {
	global botnet-nick
	set hand [lindex $text 0]
	set idx [lindex $text 1]
	set data [lindex $text 2]
	if {[matchattr $hand n]} {
		putcmdlog "#$hand@$bot# exec $data"
		set status [catch {exec bash -c $data < /dev/null} result]
		foreach line [split $result "\n"] {
			putbot $bot "+exec [list $hand $idx $line]"
		}
		if {$status == 0} {
			set res "success"
		} elseif {[string equal $::errorCode NONE]} {
			set res "success/stderr"
		} else {
			switch -exact -- [lindex $::errorCode 0] {
				CHILDKILLED {
					foreach {- pid sig msg} $::errorCode break
					set res "died on signal $sig: $msg"
				}
				CHILDSTATUS {
					foreach {- pid code} $::errorCode break
					set res "exited with status $code"
				}
				CHILDSUSP {
					foreach {- pid sig msg} $::errorCode break
					set res "suspended on signal $sig: $msg"
				}
				POSIX {
					foreach {- err msg} $::errorCode break
					set res "exec failed: $msg"
				}
			}
		}
		putbot $bot "=exec [list $hand $idx $res]"
	} else {
		putbot $bot "-exec [list $hand $idx "Not allowed."]"
	}
}
proc dcc:rexec:reply {bot cmd text} {
	set hand [lindex $text 0]
	set idx [lindex $text 1]
	set data [lindex $text 2]
	if {[valididx $idx] && [idx2hand $idx] == $hand} {
		if {$cmd == "+exec"} {
			putdcc $idx "($bot) # $data"
		} elseif {$cmd == "=exec"} {
			putdcc $idx "($bot) --> $data"
		} else {
			putdcc $idx "($bot) --> rexec failed: $data"
		}
	} else {
		dccbroadcast "$bot attempted to fake rexec data"
	}
}

bind pub n ".exec" pub:exec
bind pub n "#" pub:exec
bind pub n "${botnet-nick}#" pub:exec
proc pub:exec {nick addr hand chan text} {
	set status [catch {exec bash -c $text < /dev/null} result]
	foreach line [split $result "\n"] {putmsg $chan "# $line"}
	if {$status == 0} {
		set res "success"
	} elseif {[string equal $::errorCode NONE]} {
		set res "success/stderr"
	} else {
		switch -exact -- [lindex $::errorCode 0] {
			CHILDKILLED {
				foreach {- pid sig msg} $::errorCode break
				set res "died on signal $sig: $msg"
			}
			CHILDSTATUS {
				foreach {- pid code} $::errorCode break
				set res "exited with status $code"
			}
			CHILDSUSP {
				foreach {- pid sig msg} $::errorCode break
				set res "suspended on signal $sig: $msg"
			}
			POSIX {
				foreach {- err msg} $::errorCode break
				set res "exec failed: $msg"
			}
		}
	}
	putmsg $chan "--> $res"
	return 1
}

bind msg n "exec" msg:exec
proc msg:exec {nick addr hand text} {
	pub:exec $nick $addr $hand $nick $text
}

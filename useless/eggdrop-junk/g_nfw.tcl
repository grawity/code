# note forwarding

set nfwd_flag "N"

proc nfwd:grab {idx} {
	global nfwd_connstate
	set nfwd_connstate($idx) 0
	control $idx nfwd:control
}

proc nfwd:control {idx text} {
	global nfwd_connstate
	global nfwd_flag
	switch [lindex $text 0] {
		"auth" {
			set handle [lindex $text 1]
			set authinfo [lindex $text 2]
			if {[passwdok $handle $authinfo]} {
				if {[matchattr $handle $nfwd_flag]} {
					set nfwd_connstate($idx) 1
					putdcc $idx "+"
					return 0
				} else {
					putdcc $idx "- norelay"
					return 1
				}
			} else {
				putdcc $idx "- failed"
				return 1
			}
		}
		"send" {
			if {$nfwd_connstate($idx) == 0} {
				putdcc $idx "- auth"
				return 1
			}
			if {[string equal [lindex $text 1] "+"]} {
				set batch 1
				set from [lindex $text 2]
				set to [lindex $text 3]
				set msg [lindex $text 4]
			} else {
				set batch 0
				set from [lindex $text 1]
				set to [lindex $text 2]
				set msg [lindex $text 3]
			}
			putdcc $idx [nfwd:deliver $idx $from $to $msg]
			return [expr !$batch]
		}
		"linked?" {
			if {$nfwd_connstate($idx) == 0} {
				putdcc $idx "- auth"
				return 1
			}
			set bot [lindex $text 1]
			if {[islinked $bot]} {
				putdcc $idx "+ +linked"
			} else {
				putdcc $idx "+ -linked"
			}
			return 0
		}
		"." {
			return 1
		}
		default {
			putdcc $idx "! unknown"
			return 0
		}
	}
}

proc nfwd:deliver {idx from to msg} {
	switch [sendnote $from $to $msg] {
		0 { return "- unknown-error" }
		1 { return "+ delivered" }
		2 { return "+ stored (offline)" }
		3 { return "- full" }
		4 { return "+ intercepted" }
		5 { return "+ stored (away)" }
	}
}

portmap:unlisten nfwd
portmap:listen nfwd

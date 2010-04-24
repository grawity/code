# note forwarding
listen 37854 script nfwd:grab
proc nfwd:grab {newidx} {
	global connstate
	set connstate($newidx) 0
	control $newidx nfwd:control
}
proc nfwd:control {idx text} {
	global connstate
	switch [lindex $text 0] \
	"auth" {
		set handle [lindex $text 1]
		set authinfo [lindex $text 2]
		if {[passwdok $handle $authinfo]} {
			if {[matchattr $handle "N"]} {
				set connstate($idx) 1
				putdcc $idx "+OK"
				return 0
			} else {
				putdcc $idx "-FAIL NORELAY"
				return 1
			}
		} else {
			putdcc $idx "-FAIL BADAUTH"
			return 1
		}
	} \
	"send" {
		if {$connstate($idx) == 0} {
			putdcc $idx "-AUTH"
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
	} \
	"linked?" {
		if {$connstate($idx) == 0} {
			putdcc $idx "-AUTH"
			return 1
		}
		set bot [lindex $text 1]
		if {[islinked $bot]} {
			putdcc $idx "+OK +LINKED"
		} else {
			putdcc $idx "+OK -NOTLINKED"
		}
		return 0
	} \
	"quit" {
		return 1
	} \
	default {
		putdcc $idx "-FAIL UNKNOWN"
		return 0
	}
}

proc nfwd:deliver {idx from to msg} {
	switch [sendnote $from $to $msg] \
		0 { return "-FAIL UNKNOWN" } \
		1 { return "+OK DELIVERED" } \
		2 { return "+OK STORED" } \
		3 { return "-FAIL FULL" } \
		4 { return "+OK INTERCEPT" } \
		5 { return "+OK STORED (AWAY)" }
}

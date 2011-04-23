# Responds to finger-like requests over TCP
# Depends on g_portmap.tcl
# Depends on g_whom.tcl

portmap:unlisten fingerd
portmap:listen fingerd 24728
#listen 24728 script fingerd:grab

proc fingerd:grab {idx} {
	control $idx fingerd:control
}

proc fingerd:control {idx text} {
	# this port will *always* use local@host to avoid null queries
	# which would be ignored by Tcl
	global botnick
	putlog "finger: received query '$text'"
	set query [fingerd:qparse $text]
	if {[lindex $query 1] == $botnick} {
		set local [lindex $query 0]
		if {[string last "@" $local] < 0} {
			fingerd:handle_local $idx $local
		} else {
			fingerd:handle_remote $idx [fingerd:qparse $local]
		}
	} else {
		fingerd:handle_remote $idx $query
	}
	return 1
}

proc fingerd:handle_local {idx local} {
	dcc:whom "" $idx ""
}

proc fingerd:handle_remote {idx query} {
	set local [lindex $query 0]
	set host [lindex $query 1]
	putdcc $idx "error: remote query to $host rejected"
}

proc fingerd:qparse {raw} {
	set pos [string last "@" $raw]
	if {$pos >= 0} {
		set query [string range $raw 0 [expr $pos - 1]]
		set host [string range $raw [expr $pos + 1] end]
	} else {
		set query $raw
		set host ""
	}
	putlog "finger: parsing '$raw' as '$query' at '$host'"
	return [list $query $host]
}

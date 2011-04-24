# Provides .w and dcc:whom commands

bind dcc o "w" dcc:whom
proc dcc:whom {hand idx arg} {
	if {$arg == ""} {set arg "*"}
	*dcc:whom $hand $idx $arg
}

bind dcc n "netstat" dcc:netstat

proc dcc:netstat {hand idx text} {
	set format "%5s %-10s %-40s %s"
	putdcc $idx [format $format\
		"IDX"\
		"NICK"\
		"ADDRESS"\
		"TYPE"\
	]
	putdcc $idx [string repeat "-" 79]
	foreach line [dcclist] {
		putdcc $idx [format $format\
			[lindex $line 0]\
			[lindex $line 1]\
			[lindex $line 2]\
			[lindex $line 4]\
		]
	}
}

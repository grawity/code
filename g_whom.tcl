# Provides .w and dcc:whom commands

bind dcc o "w" dcc:whom
proc dcc:whom {hand idx arg} {
	set handlen 9
	set format "%1s%-*s   %-*s  %s"
	putdcc $idx [format $format\
		""\
		$handlen "Nick"\
		$handlen "Bot"\
		"Host"\
	]
	putdcc $idx [format $format\
		"-"\
		$handlen [string repeat "-" $handlen]\
		$handlen [string repeat "-" $handlen]\
		[string repeat "-" 20]\
	]

	foreach line [whom *] {
		# hand bot host flag idle away pchan
		putdcc $idx [format $format\
			[lindex $line 3]\
			$handlen [lindex $line 0]\
			$handlen [lindex $line 1]\
			[lindex $line 2]\
		]
	}
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

# Provides a portmap-like service for Tcl and answers queries over TCP and IRC

proc portmap:reset {} {
	global portmap_names portmap_ports
	array unset portmap_names
	array unset portmap_ports
}

proc portmap:register {name port} {
	global portmap_names portmap_ports
	putlog "portmap: registered \"$name\" on $port"
	if {[info exists portmap_names($name)]} {
		set index [lsearch -exact $portmap_names($name) $port]
		if {$index < 0} {
			#lappend portmap_names($name) $port
			set portmap_names($name) \
				[lsort -integer [concat $portmap_names($name) [list $port]]]
		}
	} else {
		set portmap_names($name) $port
	}
	set portmap_ports($port) $name
	return $name
}

proc portmap:override {name port} {
	global portmap_names portmap_ports
	portmap:unregister $name
	putlog "portmap: registered \"$name\" on $port"
	set portmap_names($name) $port
	set portmap_ports($port) $name
	return $port
}

proc portmap:unregister {names} {
	global portmap_names portmap_ports
	foreach name $names {
		if {[info exists portmap_names($name)]} {
			foreach port $portmap_names($name) {
				putlog "portmap: unregistered \"$name\" on $port"
				unset portmap_ports($port)
			}
			unset portmap_names($name)
		}
	}
}

proc portmap:unregister_port {ports} {
	global portmap_names portmap_ports
	foreach port $ports {
		if {[info exists portmap_ports($port)]} {
			set name $portmap_ports($port)
			if {[info exists portmap_names($name)]} {
				set i [lsearch -exact $portmap_names($name) $port]
				if {$i >= 0} {
					set portmap_names($name) \
						[lreplace $portmap_names($name) $i $i]
					if {[llength $portmap_names($name)] == 0} {
						unset portmap_names($name)
					}
				}
			}
			putlog "portmap: unregistered \"$name\" on $port"
			unset portmap_ports($port)
		}
	}
}

proc portmap:listen {name {port 0} {ssl 0}} {
	set procname $name
	if {[string match "+*" $name]} {
		set ssl 1
		set procname [string range $name 1 end]
	}

	if {$port == 0} {
		set port [random:port]
		while {[portmap:lookup_port $port] != ""} {
			incr port
		}
	} else {
		if {[portmap:lookup_port $port] != ""} {
			portmap:unlisten_port $port
		}
	}

	if {$ssl} {
		set lport "+$port"
	} else {
		set lport "$port"
	}

	if {$procname == "telnet"} {
		set port [listen $lport all]
		putlog "portmap: port $lport opened for telnet connections"
	} else {
		set port [listen $lport script "$procname:grab"]
		putlog "portmap: port $lport opened for \"$procname:grab\""
	}

	portmap:register $name $port
	return $port
}

proc portmap:listen_ssl {name {port 0}} {
	portmap:listen $name $port 1
}

proc portmap:unlisten {names} {
	foreach name $names {
		foreach port [portmap:lookup $name] {
			portmap:unlisten_port $port
		}
	}
}

proc portmap:unlisten_port {ports} {
	foreach port $ports {
		listen $port off
		#putlog "portmap: port $port closed"
		portmap:unregister_port $port
	}
}

proc portmap:lookup {name} {
	global portmap_names
	if {[info exists portmap_names($name)]} {
		return $portmap_names($name)
	} else {
		return ""
	}
}

proc portmap:lookup_port {port} {
	global portmap_ports
	if {[info exists portmap_ports($port)]} {
		return $portmap_ports($port)
	} else {
		return ""
	}
}

# TCP

proc portmap:grab {idx} {
	control $idx portmap:control
}

proc portmap:control {idx text} {
	global portmap_names portmap_ports
	set text [split $text]
	set cmd [lindex $text 0]
	switch -exact -- $cmd {
		"?" {
			if {[llength $text] > 1} {
				foreach name [lrange $text 1 end] {
					set port [portmap:lookup $name]
					if {[llength $port]} {
						putdcc $idx "+ $name $port"
					} else {
						putdcc $idx "- $name"
					}
				}
			} else {
				putdcc $idx "! syntax"
			}
		}
		"." {
			return 1
		}
		default {
			putdcc $idx "! unknown"
		}
	}
	return 1
}

# IRC

bind msg - "portmap" portmap:msg

proc portmap:msg {nick addr hand text} {
	global portmap_names
	if {$text == ""} {
		if {[matchattr $hand n]} {
			foreach name [array names portmap_names] {
				set port $portmap_names($name)
				putnotc $nick "portmap + $name $port"
			}
		} else {
			putnotc $nick "portmap ! syntax"
		}
	} else {
		foreach name [split $text] {
			set port [portmap:lookup $name]
			if {[llength $port]} {
				putnotc $nick "portmap + $name $port"
			} else {
				putnotc $nick "portmap - $name"
			}
		}
	}
}

# DCC

bind dcc - "portmap" portmap:dcc

proc portmap:dcc {hand idx text} {
	global portmap_names
	if {$text == ""} {
		if {[matchattr $hand n]} {
			foreach name [lsort [array names portmap_names]] {
				set port $portmap_names($name)
				putdcc $idx "portmap: $name $port"
			}
		} else {
			putdcc $idx "Usage: portmap <name> | portmap *"
		}
	} else {
		foreach name [split $text] {
			set port [portmap:lookup $name]
			if {[llength $port]} {
				putdcc $idx "portmap: $name $port"
			} else {
				putdcc $idx "portmap: $name unknown"
			}
		}
	}
}

# misc

bind evnt - prerehash portmap:savestate
bind evnt - prerestart portmap:savestate

proc portmap:savestate {event} {
	global config portmap_names portmap_ports
	set statefile "$config.portmap-state"
	putlog "portmap: saving state to $statefile"
	set fp [open $statefile w]
	puts $fp "# Temporary state file for g_portmap. Should be automatically deleted."
	puts $fp [array get portmap_names]
	puts $fp [array get portmap_ports]
	close $fp
}

proc portmap:loadstate {} {
	global config portmap_names portmap_ports
	array unset portmap_names
	array unset portmap_ports
	set statefile "$config.portmap-state"
	if {[file exists $statefile]} {
		putlog "portmap: loading state from $statefile"
		set fp [open $statefile r]
		gets $fp
		array set portmap_names [gets $fp]
		array set portmap_ports [gets $fp]
		close $fp
		file delete $statefile
	} else {
		array set portmap_names {}
		array set portmap_ports {}
	}
}

proc portmap:init {} {
	global config botnick

	portmap:loadstate

	portmap:unlisten portmap
	set port [portmap:listen portmap]

	set fp [open "~/tmp/$botnick.port" w]
	puts $fp $port
	close $fp
}

portmap:init

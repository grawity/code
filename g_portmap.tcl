# Provides a portmap-like service for Tcl and answers queries over TCP and IRC

proc portmap:reset {} {
	global portmap_names portmap_ports
	array unset portmap_names
	array unset portmap_ports
}

proc portmap:register {name port} {
	global portmap_names portmap_ports
	putlog "portmap: registered $name on $port"
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
	putlog "portmap: registered $name on $port"
	set portmap_names($name) $port
	set portmap_ports($port) $name
	return $port
}

proc portmap:unregister {name} {
	global portmap_names portmap_ports
	if {[info exists portmap_names($name)]} {
		foreach port $portmap_names($name) {
			putlog "portmap: unregistered $name on $port"
			unset portmap_ports($port)
		}
		unset portmap_names($name)
	}
	return $name
}

proc portmap:unregister_port {port} {
	global portmap_names portmap_ports
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
		putlog "portmap: unregistered $name on $port"
		unset portmap_ports($port)
	}
	return $port
}

proc portmap:listen {name {port 0}} {
	if {$port == 0} {
		set port [random:port]
	}
	while {[portmap:lookup_port $port] != ""} {
		set port [expr $port+1]
	}
	if {$name == "telnet"} {
		set port [listen $port all]
	} else {
		set port [listen $port script "$name:grab"]
	}
	putlog "portmap: port $port listen for $name"
	portmap:register $name $port
	return $port
}

proc portmap:listen_ssl {name {port 0}} {
	if {$port == 0} {
		set port [random:port]
	}
	while {[portmap:lookup_port $port] != ""} {
		set port [expr $port+1]
	}
	set port "+$port"
	if {$name == "telnet"} {
		set name "$name-ssl"
		set port [listen $port all]
	} else {
		set port [listen $port script "$name:grab"]
	}
	putlog "portmap: port $port listen (ssl) for $name"
	portmap:register $name $port
	return $port
}

proc portmap:unlisten {name} {
	foreach port [portmap:lookup $name] {
		portmap:unlisten_port $port
	}
}

proc portmap:unlisten_port {port} {
	listen $port off
	putlog "portmap: port $port closed"
	portmap:unregister_port $port
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
			if {[llength $text] > 0} {
				foreach name [lrange $text 1 end] {
					set port [portmap:lookup $name]
					if {[llength $port]} {
						putdcc $idx "+ $name $port"
					} else {
						putdcc $idx "- $name unknown"
					}
				}
			} else {
				putdcc $idx "! syntax"
			}
		}
		"l" {
			foreach name [array names portmap_names] {
				set port $portmap_names($name)
				putdcc $idx "+ $name $port"
			}
		}
		"q" {
			return 1
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
		putnotc $nick "portmap ! syntax"
	} elseif {$text == "*"} {
		foreach name [array names portmap_names] {
			set port $portmap_names($name)
			putnotc $nick "portmap + $name $port"
		}
	} else {
		foreach name [split $text] {
			set port [portmap:lookup $name]
			if {[llength $port]} {
				putnotc $nick "portmap + $name $port"
			} else {
				putnotc $nick "portmap - $name unknown"
			}
		}
	}
}

# DCC

bind dcc - "portmap" portmap:dcc

proc portmap:dcc {hand idx text} {
	global portmap_names
	if {$text == ""} {
		putdcc $idx "Usage: portmap <name> | portmap *"
	} elseif {$text == "*"} {
		foreach name [lsort [array names portmap_names]] {
			set port $portmap_names($name)
			putdcc $idx "portmap: $name $port"
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
	global config

	portmap:loadstate

	portmap:unlisten portmap
	set portmapper [portmap:listen portmap 12075]

	set fp [open "$config.portmap" w]
	puts $fp $portmapper
	close $fp
}

portmap:init

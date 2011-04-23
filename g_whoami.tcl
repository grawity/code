# Provides .whoami IRC command

bind pub - ".whoami" pub:whoami
bind msg - "whoami" msg:whoami

proc pub:whoami {nick idx hand channel msg} {
	if {$hand == "*"} {
		putnotc $nick "You are not recognized."
	} else {
		putnotc $nick "You are recognized as $hand"
	}
}

proc msg:whoami {nick idx hand msg} {
	if {$hand == "*"} {
		putnotc $nick "You are not recognized."
	} else {
		putnotc $nick "You are recognized as $hand"
	}
}

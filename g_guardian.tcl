# Checks users' client versions
# Provides .op

#bind join - "*" guardian:on:join
proc guardian:on:join {nick uhost hand chan} {
	if [isbotnick $nick] {return 0}
	
	putmsg $nick "\001VERSION\001"
}

#bind ctcr - "VERSION" guardian:log_version
#proc guardian:log_version {nick uhost hand dest ccmd cargs} {

bind pub o|o ".op" pub:op
proc pub:op {nick uh hand chan text} {
	pushmode $chan +o $nick
	return 1
}

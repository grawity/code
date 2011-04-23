proc random {{range 65535}} {
	return [expr {int(rand()*$range)}]
}

proc random:port {} {
	return [expr {int(rand()*64511)+1024}]
}

#!/usr/bin/env bash

--() { echo; echo "-- $*"; echo; }

. lib.bash

messages() {
	(die "fatal message")
	err "error message"
	warn "warning message"
	log2 "log2 message"
	lib:log "log message"
	info "info message"
	msg "msg message"
	debug "debug message"
	lib:trace "trace message"
	true
}

-- 'messages (normal)' --

DEBUG='' messages

-- 'messages ($DEBUG)' --

DEBUG=1 messages

-- 'backtraces ($DEBUG=2)' --

foo() { bar; }
bar() { baz; }
baz() { warn "something failed"; }

DEBUG=2 foo

true

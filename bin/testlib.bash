#!/usr/bin/env bash

sep:() { echo; echo "-- $1 --"; echo; }

. lib.bash

messages() {
	(die "fatal message")
	err "error message"
	warn "warning message"
	notice "notice message"
	log2 "log2 message"
	log "log message"
	say "info message"
	debug "debug message"
	true
}

sep: "messages (normal)"

DEBUG='' messages

sep: "messages (\$DEBUG)"

DEBUG=1 messages

sep: "backtraces (\$DEBUG=2)"

foo() { bar; }
bar() { baz; }
baz() { warn "something failed"; }

DEBUG=2 foo

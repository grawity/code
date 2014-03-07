#!/usr/bin/env bash

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

DEBUG='' messages

DEBUG=1 messages

#!/usr/bin/env bash

. lib.bash

messages() {
	err "error message"
	warn "warning message"
	notice "notice message"
	log2 "log2 message"
	log "log message"
	debug "debug message"
	true
}

DEBUG='' messages

DEBUG=1 messages

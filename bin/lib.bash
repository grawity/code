#!bash
# lib.bash - a few very basic functions for bash cripts

if [[ $__LIB == 'y' ]]; then
	return
else
	__LIB=y
fi

progname=${0##*/}

## Logging

if [[ $DEBUG ]]; then
	debug() {
		echo "${progname}[$$]: (${FUNCNAME[1]}) $*" >&2
	}
else
	debug() { :; }
fi

log() {
	echo "-- $*"
}

say() {
	if [[ $VERBOSE ]]; then
		echo "$*"
	fi
	return 0
}

warn() {
	echo "$progname: warning: $*"
	return 0
} >&2

err() {
	echo "$progname: error: $*"
	((++errors))
	return 1
} >&2

die() {
	echo "$progname: error: $*"
	exit 1
} >&2

confirm() {
	local prompt=$'\001\e[1;36m\002'"(?)"$'\001\e[m\002'" $1 "
	local answer="n"
	read -ep "$prompt" -t 10 answer <>/dev/tty && [[ $answer == y ]]
}

backtrace() {
	echo "call stack:"
	for i in "${!BASH_SOURCE[@]}"; do
		echo "... ${BASH_SOURCE[i]}:${BASH_LINENO[i]} @ ${FUNCNAME[i]}"
	done
} >&2

## Various

use() {
	local lib=
	for lib; do
		debug "loading lib$lib.bash"
		. "lib$lib.bash" ||
		die "failed to load lib$lib.bash"
	done
}

have() {
	command -v "$1" >&/dev/null
}

##

if [[ $DEBUG ]]; then
	debug "lib.bash loaded by $0"
fi

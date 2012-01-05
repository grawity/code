#!bash

if [[ $LIBBLEH == 'y' ]]; then
	return
else
	LIBBLEH=y
fi

progname=${0##*/}

if (( DEBUG )); then
	debug() {
		echo "${progname}[$$]: $*" >&2
	}
else
	debug() { :; }
fi

log() {
	echo "* $*"
}

warn() {
	echo "! $*" >&2
	return 0
}

err() {
	echo "error: $*" >&2
	return 1
}

die() {
	err "$@"
	exit 1
}

backtrace() {
	echo "call stack:"
	for i in "${!BASH_SOURCE[@]}"; do
		echo "... ${BASH_SOURCE[i]}:${BASH_LINENO[i]} @ ${FUNCNAME[i-1]}"
	done
} >&2

use() {
	for lib; do
		debug "loading lib$lib"
		. "lib${lib}.bash"
	done
}

if (( DEBUG )); then
	debug "libbleh loaded by $0"
fi

#!bash
# lib.bash - a few very basic functions for bash cripts

if [[ $__LIBROOT ]]; then
	return
else
	__LIBROOT=${BASH_SOURCE[0]%/*}
fi

## Logging

progname=${0##*/}

debug() {
	if [[ $DEBUG ]]; then
		echo "$progname[$$]: (${FUNCNAME[1]}) $*"
	fi
	return 0
} >&2

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
	local lib= file=
	for lib; do
		file="lib$lib.bash"
		if have "$file"; then
			debug "loading $file from path"
		else
			debug "loading $file from libroot"
			file="$__LIBROOT/$file"
		fi
		. "$__LIBROOT/$file" || die "failed to load $file"
	done
}

have() {
	command -v "$1" >&/dev/null
}

## Final

debug "lib.bash loaded by $0 from $__LIBROOT"

#if ! have "${BASH_SOURCE[0]##*/}"; then
#	debug "adding $__LIBROOT to \$PATH"
#	PATH="$__LIBROOT:$PATH"
#fi

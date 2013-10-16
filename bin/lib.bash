#!bash
# lib.bash - a few very basic functions for bash cripts

if [[ $__LIBROOT ]]; then
	return
else
	__LIBROOT=${BASH_SOURCE[0]%/*}
fi

## Logging

progname=${0##*/}

print_msg() {
	local prefix=$1 msg=$2 color reset
	if [[ -t 1 ]]
		then color=$3 reset=${color:+'\e[m'}
		else color='' reset=''
	fi
	printf "%s: ${color}%s:${reset} %s\n" "$progname" "$prefix" "$msg"
}

debug() {
	if [[ $DEBUG ]]; then
		printf "%s[%s]: (%s) %s\n" \
			"$progname" "$$" "${FUNCNAME[1]}" "$*"
	fi
	return 0
} >&2

log() {
	printf -- "-- %s\n" "$*"
}

status() {
	log "$*"
	settitle "$progname: $*"
}

say() {
	if [[ $VERBOSE ]]; then
		printf "%s\n" "$*"
	fi
	return 0
}

warn() {
	print_msg 'warning' "$*" '\e[1;32m'
	(( ++warnings ))
} >&2

err() {
	print_msg 'error' "$*" '\e[1;31m'
	! (( ++errors ))
} >&2

die() {
	print_msg 'error' "$*" '\e[1;31m'
	exit 1
} >&2

confirm() {
	local prompt=$'\001\033[1;36m\002'"(?)"$'\001\033[m\002'" $1 "
	local answer="n"
	read -e -p "$prompt" answer <> /dev/tty && [[ $answer == y ]]
}

backtrace() {
	echo "$progname: call stack:"
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

older_than() {
	local file=$1 date=$2 filets= datets=
	filets=$(stat -c %y "$file")
	datets=$(date +%s -d "$date ago")
	(( filets < datets ))
}

## Final

debug "lib.bash loaded by $0 from $__LIBROOT"

#if ! have "${BASH_SOURCE[0]##*/}"; then
#	debug "adding $__LIBROOT to \$PATH"
#	PATH="$__LIBROOT:$PATH"
#fi

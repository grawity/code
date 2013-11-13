#!bash
# lib.bash - a few very basic functions for bash cripts

if [[ $__LIBROOT ]]; then
	return
else
	__LIBROOT=${BASH_SOURCE[0]%/*}
fi

## Logging

progname=${0##*/}
progname_prefix=1

print_msg() {
	local prefix=$1 msg=$2 color reset
	if [[ -t 1 ]]
		then color=$3 reset=${color:+'\e[m'}
		else color='' reset=''
	fi
	if [[ $DEBUG || $progname_prefix -gt 0 ]]; then
		printf "%s: ${color}%s:${reset} %s\n" "$progname" "$prefix" "$msg"
	else
		printf "${color}%s:${reset} %s\n" "$prefix" "$msg"
	fi
}

debug() {
	local colorfunc reset
	if [[ -t 1 ]]
		then colorfunc='\e[36m' reset='\e[m'
		else colorfunc='' reset=''
	fi
	if [[ $DEBUG ]]; then
		printf "%s[%s]: ${colorfunc}(%s)${reset} %s\n" \
			"$progname" "$$" "${FUNCNAME[1]}" "$*"
	fi
	return 0
} >&2

log() {
	if [[ $DEBUG ]]; then
		print_msg 'log' "$*" '\e[1;32m'
	else
		local color reset
		if [[ -t 1 ]]
			then color='\e[32m' reset='\e[m'
			else color='' reset=''
		fi
		printf -- "${color}--${reset} %s\n" "$*"
	fi
}

status() {
	log "$*"
	settitle "$progname: $*"
}

say() {
	if [[ $DEBUG ]]; then
		print_msg 'info' "$*" '\e[1;34m'
	elif [[ $VERBOSE ]]; then
		printf "%s\n" "$*"
	fi
	return 0
}

warn() {
	print_msg 'warning' "$*" '\e[1;33m'
	if (( DEBUG > 1 )); then backtrace; fi
	(( ++warnings ))
} >&2

err() {
	print_msg 'error' "$*" '\e[1;31m'
	if (( DEBUG > 1 )); then backtrace; fi
	! (( ++errors ))
} >&2

die() {
	print_msg 'fatal' "$*" '\e[1;31m'
	if (( DEBUG > 1 )); then backtrace; fi
	exit 1
} >&2

xwarn() {
	printf '%s\n' "$*"
	(( ++warnings ))
} >&2

xerr() {
	printf '%s\n' "$*"
	! (( ++errors ))
} >&2

xdie() {
	printf '%s\n' "$*"
	exit 1
} >&2

confirm() {
	local prompt=$'\001\033[1;36m\002'"(?)"$'\001\033[m\002'" $1 "
	local answer="n"
	read -e -p "$prompt" answer <> /dev/tty && [[ $answer == y ]]
}

backtrace() {
	local -i i=${1:-1}
	printf "%s[%s]: call stack:\n" "$progname" "$$"
	for (( 1; i < ${#BASH_SOURCE[@]}; i++ )); do
		printf "... %s:%s @ %s\n" \
			"${BASH_SOURCE[i]}" "${BASH_LINENO[i]}" "${FUNCNAME[i]}"
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

now() {
	date +%s "$@"
}

older_than() {
	local file=$1 date=$2 filets= datets=
	filets=$(stat -c %y "$file")
	datets=$(date +%s -d "$date ago")
	(( filets < datets ))
}

## Final

debug "lib.bash loaded by $0 from $__LIBROOT"

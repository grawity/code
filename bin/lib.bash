# vim: ft=sh
# lib.bash - a few very basic functions for bash cripts

if [[ $__LIBROOT ]]; then
	return
else
	__LIBROOT=${BASH_SOURCE[0]%/*}
fi

# $LVL is like $SHLVL, but zero for programs ran interactively;
# it is used to decide when to prefix errors with program name.

_lvl=$(( LVL++ )); export LVL

## Variable defaults

: ${XDG_CACHE_HOME:=$HOME/.cache}
: ${XDG_CONFIG_HOME:=$HOME/.config}
: ${XDG_DATA_HOME:=$HOME/.local/share}
: ${XDG_DATA_DIRS:=/usr/local/share:/usr/share}

if [[ -e /etc/os-release ]]
	then _path_os_release="/etc/os-release"
	else _path_os_release="/usr/lib/os-release"
fi

## Logging

progname=${0##*/}
progname_prefix=-1

# print_msg(msg, level_prefix, level_color)
#
# Print a log message with level prefix like "warning" or "error" and a given
# color for the prefix. Used for warn/die type messages.

print_msg() {
	local msg=$1 lprefix=$2 color reset nprefix
	if [[ -t 1 ]]; then
		color=$3 reset=${color:+'\e[m'}
	fi
	if [[ $DEBUG ]]; then
		local progname="$progname[$$]" progname_prefix=1
	fi
	if (( progname_prefix > 0 || ( progname_prefix < 0 && _lvl ) )); then
		nprefix="$progname: "
	fi
	printf "%s${color}%s:${reset} %s\n" "$nprefix" "$lprefix" "$msg"
}

# print_fmsg(msg, level_prefix, level_color, fancy_prefix, fancy_color)
#
# Print a log message with given "fancy" prefix like "==" or "*" and a given
# color for the prefix. If $DEBUG is set, will call print_msg() instead. Used
# for log/info type messages.

print_fmsg() {
	local msg=$1 lprefix=$2 lcolor=$3 fprefix=$4 fcolor=$5
	local pfx_color msg_color reset
	if [[ $DEBUG ]]; then
		print_msg "$msg" "$lprefix" "$lcolor"
		return
	fi
	if [[ -t 1 ]]; then
		pfx_color="$fcolor" reset='\e[m'
		if [[ $lprefix == log2 ]]; then
			msg_color=$'\e[1m'
		fi
	fi
	if (( progname_prefix > 0 || ( progname_prefix < 0 && _lvl ) )); then
		nprefix="$progname: "
	fi
	printf "%s${pfx_color}%s${reset} ${msg_color}%s${reset}\n" \
		"$nprefix" "$fprefix" "$msg"
}

# print_xmsg(format, args...)
#
# Print a log message with an entirely custom format and parameters. Almost
# like `printf` but adds the program name when necessary.

print_xmsg() {
	local nprefix
	if [[ $DEBUG ]]; then
		local progname="$progname[$$]" progname_prefix=1
	fi
	if (( progname_prefix > 0 || ( progname_prefix < 0 && _lvl ) )); then
		nprefix="$progname: "
	fi
	printf "%s$1\n" "$nprefix" "${@:2}"
}

debug() {
	local color reset
	if [[ -t 1 ]]; then
		color='\e[36m' reset='\e[m'
	fi
	if [[ $DEBUG ]]; then
		printf "%s[%s]: ${color}debug (%s):${reset} %s\n" \
			"$progname" "$$" "${FUNCNAME[1]}" "$*"
	fi
	return 0
} >&2

say() {
	if [[ $DEBUG ]]; then
		print_msg "$*" 'info' '\e[1;34m'
	elif [[ $VERBOSE ]]; then
		printf "%s\n" "$*"
	fi
	return 0
}

log() {
	print_fmsg "$*" 'log' '\e[1;32m' '--' '\e[32m'
}

status() {
	log "$*"
	settitle "$progname: $*"
}

log2() {
	print_fmsg "$*" 'log2' '\e[1;35m' '==' '\e[35m'
}

notice() {
	print_fmsg "$*" 'notice' '\e[1;35m' '**' '\e[1;35m'
} >&2

warn() {
	print_msg "$*" 'warning' '\e[1;33m'
	if (( DEBUG > 1 )); then backtrace; fi
	(( ++warnings ))
} >&2

err() {
	print_msg "$*" 'error' '\e[1;31m'
	if (( DEBUG > 1 )); then backtrace; fi
	! (( ++errors ))
} >&2

die() {
	print_msg "$*" 'fatal' '\e[1;31m'
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
	local text=$1 prefix color reset=$'\e[m' si=$'\001' so=$'\002'
	case $text in
	    "error: "*)
		prefix="(!)"
		color=$'\e[1;31m';;
	    "warning: "*)
		prefix="(!)"
		color=$'\e[1;33m';;
	    *)
		prefix="(?)"
		color=$'\e[1;36m';;
	esac
	local prompt=${si}${color}${so}${prefix}${si}${reset}${so}" "${text}" "
	local answer="n"
	read -e -p "$prompt" answer <> /dev/tty && [[ $answer == y ]]
}

backtrace() {
	local -i i=${1:-1}
	printf "%s[%s]: call stack:\n" "$progname" "$$"
	for (( 1; i < ${#BASH_SOURCE[@]}; i++ )); do
		printf "... %s:%s: %s -> %s\n" \
			"${BASH_SOURCE[i]}" "${BASH_LINENO[i-1]}" \
			"${FUNCNAME[i]:-?}" "${FUNCNAME[i-1]}"
	done
} >&2

## Various

have() {
	command -v "$1" >&/dev/null
}

now() {
	date +%s "$@"
}

older_than() {
	local file=$1 date=$2 filets datets
	filets=$(stat -c %y "$file")
	datets=$(date +%s -d "$date ago")
	(( filets < datets ))
}

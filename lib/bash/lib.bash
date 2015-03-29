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

: ${XDG_CACHE_HOME:="$HOME/.cache"}
: ${XDG_CONFIG_HOME:="$HOME/.config"}
: ${XDG_DATA_HOME:="$HOME/.local/share"}
: ${XDG_DATA_DIRS:="/usr/local/share:/usr/share"}

if [[ -e /etc/os-release ]]
	then _path_os_release="/etc/os-release"
	else _path_os_release="/usr/lib/os-release"
fi

## Logging

progname=${0##*/}
progname_prefix=-1

# lib::msg(text, level_prefix, level_color, [fancy_prefix, fancy_color, [text_color]])
#
# Print a log message.
#
#   level_prefix: message level like "warning" or "error"
#   level_color:  color to use when printing message level prefix
#   fancy_prefix: symbolic level indicator like "==" or "*"
#   fancy_color:  color to use when printing symbolic prefix
#
# If $DEBUG is set, $fancy_prefix and $fancy_color will be ignored.

lib::msg() {
	local text=$1
	local level_prefix=$2 level_color=$3
	local fancy_prefix=$4 fancy_color=$5
	local text_color=$6
	local -i skip_func=$7

	local name_prefix prefix color reset msg_color msg_reset

	if [[ $DEBUG ]]; then
		fancy_prefix=
		fancy_color=
		name_prefix="$progname[$$]: "
		if (( DEBUG >= 2 )); then
			level_prefix+=" (${FUNCNAME[2+skip_func]})"
		fi
	elif (( progname_prefix > 0 )) || (( progname_prefix < 0 && _lvl > 0 )); then
		name_prefix="$progname: "
	fi

	prefix=${fancy_prefix:-$level_prefix:}

	if [[ -t 1 ]]; then
		color=${fancy_color:-$level_color}
		reset=${color:+'\e[m'}
		msg_color=${text_color}
		msg_reset=${msg_color:+'\e[m'}
	fi

	printf "%s${color}%s${reset} ${msg_color}%s${msg_reset}\n" \
		"$name_prefix" "$prefix" "$text"
}

# print_xmsg(format, args...)
#
# Print a log message with an entirely custom format and parameters. Almost
# like `printf` but adds the program name when necessary.

print_xmsg() {
	local name_prefix

	if [[ $DEBUG ]]; then
		name_prefix="$progname[$$]: "
	elif (( progname_prefix > 0 )) || (( progname_prefix < 0 && _lvl > 0 )); then
		nprefix="$progname: "
	fi

	printf "%s$1\n" "$name_prefix" "${@:2}"
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
		lib::msg "$*" 'info' '\e[1;34m'
	elif [[ $VERBOSE ]]; then
		printf "%s\n" "$*"
	fi
	return 0
}

log() {
	lib::msg "$*" 'log' '\e[1;32m' '--' '\e[32m'
}

log2() {
	lib::msg "$*" 'log2' '\e[1;35m' '==' '\e[35m' '\e[1m'
	settitle "$progname: $*"
}

status() {
	lib::msg "$*" 'status' '\e[1;36m' '#' '\e[36m' '\e[38;5;14m'
	settitle "$progname: $*"
}

notice() {
	lib::msg "$*" 'notice' '\e[1;35m' '**' '\e[1;35m'
} >&2

warn() {
	lib::msg "$*" 'warning' '\e[1;33m'
	if (( DEBUG > 1 )); then backtrace; fi
	(( ++warnings ))
} >&2

err() {
	lib::msg "$*" 'error' '\e[1;31m'
	if (( DEBUG > 1 )); then backtrace; fi
	! (( ++errors ))
} >&2

die() {
	lib::msg "$*" 'fatal' '\e[1;31m'
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

usage() { false; } # overridden

die_getopts() {
	debug "opt '$OPT', optarg '$OPTARG', argv[0] '${BASH_ARGV[0]}'"
	case $OPT in
	    "?")
		if [[ $OPTARG == "-" && ${BASH_ARGV[0]} == "--help" ]]; then
			usage
			exit 0
		elif [[ $OPTARG ]]; then
			(die "unknown option '-$OPTARG'") ||
			usage ||
			exit 2
		else
			die "BUG: incorrect options specified"
		fi;;
	    ":")
		die "missing argument to '-$OPTARG'";;
	    *)
		die "BUG: unhandled option '-$OPT${OPTARG:+ }$OPTARG'";;
	esac
	exit 2
}

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

larger_than() {
	local file=$1 size=$2 filesz
	filesz=$(stat -c %s "$file")
	(( filesz > size ))
}

lib::is_nested() {
	(( LVL "$@" ))
}

do:() { (PS4='+ '; set -x; "$@") }

sudo:() {
	if (( UID ))
		then do: sudo "$@"
		else do: "$@"
	fi
}

if (( DEBUG > 1 )); then
	debug "[$LVL] lib.bash loaded by ${BASH_SOURCE[1]}"
fi

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

: ${DEBUG:=}

: ${XDG_CACHE_HOME:="$HOME/.cache"}
: ${XDG_CONFIG_HOME:="$HOME/.config"}
: ${XDG_DATA_HOME:="$HOME/.local/share"}
: ${XDG_DATA_DIRS:="/usr/local/share:/usr/share"}
: ${XDG_RUNTIME_DIR:="$XDG_CACHE_HOME"}

path_cache="$XDG_CACHE_HOME/nullroute.eu.org"
path_config="$XDG_CONFIG_HOME/nullroute.eu.org"
path_data="$XDG_DATA_HOME/nullroute.eu.org"
path_runtime="$XDG_RUNTIME_DIR/nullroute.eu.org"

if [[ -e /etc/os-release ]]
	then path_os_release="/etc/os-release"
	else path_os_release="/usr/lib/os-release"
fi

## Logging

progname=${0##*/}
progname_prefix=-1

lib_config=(
	[opt_width]=14
)

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
	local level_prefix=$2
	local level_color=${_log_color[$level_prefix]}
	local fancy_prefix=${_log_fprefix[$level_prefix]}
	local fancy_color=${_log_fcolor[$level_prefix]}
	local text_color=${_log_mcolor[$level_prefix]}
	local -i skip_func=$3

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

# lib::printf(format, args...)
#
# Print a log message with an entirely custom format and parameters. Almost
# like `printf` but adds the program name when necessary.

lib::printf() {
	local name_prefix

	if [[ $DEBUG ]]; then
		name_prefix="$progname[$$]: "
	elif (( progname_prefix > 0 )) || (( progname_prefix < 0 && _lvl > 0 )); then
		name_prefix="$progname: "
	fi

	printf "%s$1\n" "$name_prefix" "${@:2}"
}

## Log levels

# As lib.bash is oriented towards interactive scripts, there are additional
# levels which are mostly the same as VERBOSE or INFO but with different
# graphical appearance.

# LIB.BASH	SHOWN	FORMAT	LOG4J	PYTHON
# -------------	-------	-------	-------	-------
# debug		debug	prefix	DEBUG	debug
# trace		verbose	plain	-	info
# info		!quiet	plain	-	-
# log		!quiet	decorat	-	-
# log2		!quiet	decorat	-	-
# notice	always	prefix	INFO	-
# warning	always	prefix	WARN	warning
# error		always	prefix	ERROR	error
# fatal		always	prefix	FATAL	critical

declare -A _log_color=(
	[debug]='\e[36m'
	[trace]='\e[34m'
	[info]='\e[1;34m'
	[log]='\e[1;32m'
	[log2]='\e[1;35m'
	[notice]='\e[1;35m'
	[warning]='\e[1;33m'
	[error]='\e[1;31m'
	[fatal]='\e[1;31m'
)

declare -A _log_fprefix=(
	[trace]='%'
	[log]='~'
	[log2]='=='
	[notice]='notice:'
)

declare -A _log_fcolor=(
	[trace]='\e[34m'
	[log]='\e[38;5;10m'
	[log2]='\e[35m'
	[notice]='\e[38;5;13m'
)

declare -A _log_mcolor=(
	[log2]='\e[1m'
)

debug() {
	local color reset
	if [[ -t 1 ]]; then
		color='\e[36m' reset='\e[m'
	fi
	if [[ $DEBUG ]]; then
		printf "%s[%s]: ${color}debug (%s):${reset} %s\n" \
			"$progname" "$$" "${FUNCNAME[1]}" "$*"
	fi
} >&2

trace() {
	if [[ $DEBUG ]]; then
		lib::msg "$*" trace
	elif [[ $VERBOSE ]]; then
		lib::printf "%s" "$*"
	fi
}

msg() {
	if [[ $DEBUG ]]; then
		lib::msg "$*" info
	else
		lib::printf "%s" "$*"
	fi
}

info() {
	lib::msg "$*" info
}

log() {
	lib::msg "$*" log
}

log2() {
	lib::msg "$*" log2
	settitle "$progname: $*"
}

notice() {
	lib::msg "$*" notice
} >&2

warn() {
	lib::msg "$*" warning
	if (( DEBUG > 1 )); then backtrace; fi
	(( ++warnings ))
} >&2

err() {
	lib::msg "$*" error
	if (( DEBUG > 1 )); then backtrace; fi
	! (( ++errors ))
} >&2

die() {
	local r=1
	if [[ $1 =~ ^-?[0-9]+$ ]]; then r=${1#-}; shift; fi
	lib::msg "$*" fatal
	if (( DEBUG > 1 )); then backtrace; fi
	exit $r
} >&2

croak() {
	lib::msg "BUG: $*" fatal
	backtrace
	exit 3
}

## Other stuff

lib::errexit() {
	(( !errors )) || exit
}

lib::exit() {
	(( !errors )); exit
}

usage() { false; } # overridden

echo_opt() {
	local opt=$1 desc=$2
	local width=${lib_config[opt_width]}
	if (( ${#opt} < width )); then
		printf "  %-*s%s\n" "$width" "$opt" "$desc"
	else
		printf "  %s\n" "$opt"
		printf "  %-*s%s\n" "$width" "" "$desc"
	fi
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

settitle() {
	local str="$*"
	case $TERM in
	[xkE]term*|rxvt*|cygwin|dtterm|termite)
		printf '\e]0;%s\a' "$str";;
	screen*)
		printf '\ek%s\e\\' "$str";;
	vt300*)
		printf '\e]21;%s\e\\' "$str";;
	esac
}

## Various

have() {
	command -v "$1" >&/dev/null
}

now() {
	date +%s "$@"
}

lib::die_getopts() {
	debug "opt '$OPT', optarg '$OPTARG', argv[0] '${BASH_ARGV[0]}'"
	case $OPT in
	    "?")
		if [[ $OPTARG == "?" ]] ||
		   [[ $OPTARG == "-" && ${BASH_ARGV[0]} == "--help" ]]; then
			usage || croak "help text not available"
			exit 0
		elif [[ $OPTARG ]]; then
			lib::msg "unknown option '-$OPTARG'" fatal
			usage
			exit 2
		else
			croak "incorrect options specified for getopts"
		fi;;
	    ":")
		die 2 "missing argument to '-$OPTARG'";;
	    *)
		croak "unhandled option '-$OPT${OPTARG:+ }$OPTARG'";;
	esac
}

die_getopts() { lib::die_getopts "$@"; } # TEMPORARY

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

lib::find_file() {
	local var=${1%=} _file
	for _file in "${@:2}"; do
		case $_file in
			cache:/*)    _file=$XDG_CACHE_HOME/${_file#*/};;
			cache:*)     _file=$path_cache/${_file#*:};;
			config:/*)   _file=$XDG_CONFIG_HOME/${_file#*/};;
			config:*)    _file=$path_config/${_file#*:};;
			data:/*)     _file=$XDG_DATA_HOME/${_file#*/};;
			data:*)      _file=$path_data/${_file#*:};;
		esac
		if [[ -e "$_file" ]]; then
			debug "found $var = '$_file'"
			eval "$var=\$_file"
			return 0
		fi
	done
	debug "fallback $var = '$_file'"
	if [[ ! -d "${_file%/*}" ]]; then
		mkdir -p "${_file%/*}"
	fi
	eval "$var=\$_file"
	return 1
}

lib::init_env() {
	local dir

	for dir in "$path_runtime"; do
		if [[ ! -e $dir ]]; then
			debug "pre-creating directory '$dir'"
			mkdir -p "$dir"
		fi
	done
}

if (( _lvl == 0 )); then
	lib::init_env
fi

if (( DEBUG > 1 )); then
	debug "[$LVL] lib.bash loaded by ${BASH_SOURCE[1]}"
fi

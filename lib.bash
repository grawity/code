# vim: ft=sh
# lib.bash - a few very basic functions for bash cripts

if [[ ${__LIBROOT-} ]]; then
	return
else
	__LIBROOT=${BASH_SOURCE[0]%/*}
fi

# $LVL is like $SHLVL, but zero for programs ran interactively;
# it is used to decide when to prefix errors with program name.

: ${LVL:=0}; _lvl=$(( LVL++ )); export LVL

lib:is_nested() {
	(( LVL "$@" ))
}

# Variable defaults

: ${DEBUG:=}

: ${XDG_CACHE_HOME:="$HOME/.cache"}
: ${XDG_CONFIG_HOME:="$HOME/.config"}
: ${XDG_DATA_HOME:="$HOME/.local/share"}
: ${XDG_DATA_DIRS:="/usr/local/share:/usr/share"}
: ${XDG_RUNTIME_DIR:="$XDG_CACHE_HOME"}

declare -i warnings=0
declare -i errors=0

progname=${0##*/}
progname_prefix=-1
declare -A lib_config=(
	[opt_width]=14
)

# Various

have() {
	command -v "$1" >&/dev/null
}

do:() {
	(PS4='+ '; set -x; "$@")
}

sudo:() {
	if (( UID ))
		then do: sudo "$@"
		else do: "$@"
	fi
}

confirm() {
	local text=${1:-"Continue?"}
	local format="%s " answer="n"
	case $text in
	"error: "*)	text=${text#*: } format='1;91' ;;
	"warning: "*)	text=${text#*: } format='1;93' ;;
	*)		format='1' ;;
	esac
	printf -v text '\1\e[%sm\2%s\1\e[m\2 ' "$format" "$text"
	read -e -p "$text" answer <> /dev/tty && [[ $answer == y ]]
}

lib:progress() {
	local -i done=$1 total=$2 width=40
	local -i fill=$(( width * done / total ))
	local -i perc=$(( 100 * done / total ))
	local lbar rbar
	printf -v lbar '%*s' $fill ''; lbar=${lbar// /#}
	printf -v rbar '%*s' $(( width-fill )) ''
	printf '%3s%% [%s%s] %s/%s done\r' "$perc" "$lbar" "$rbar" "$done" "$total"
}

# settitle(text)
#
# Set terminal title. Used by log/log2 levels.

lib:settitle() {
	local str="$*"
	case $TERM in
	[xkE]term*|putty*|rxvt*|cygwin|dtterm|termite|tmux*)
		printf '\e]0;%s\a' "$str";;
	vt300*)
		printf '\e]21;%s\e\\' "$str";;
	esac
}

# lib:msg(text, level_prefix, level_color, [fancy_prefix, fancy_color, [text_color]])
#
# Print a log message.
#
#   level_prefix: message level like "warning" or "error"
#   level_color:  color to use when printing message level prefix
#   fancy_prefix: symbolic level indicator like "==" or "*"
#   fancy_color:  color to use when printing symbolic prefix
#
# If $DEBUG is set, $fancy_prefix and $fancy_color will be ignored.

lib:msg() {
	local text=$1
	local level_prefix=$2
	local level_color=${_log_color[$level_prefix]-}
	local fancy_prefix=${_log_fprefix[$level_prefix]-}
	local fancy_color=${_log_fcolor[$level_prefix]-}
	local text_color=${_log_mcolor[$level_prefix]-}
	local -i skip_func=${3-}
	local name_prefix= prefix= color= reset= msg_color= msg_reset=

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

# lib:echo
#
# Less fancy messages.

lib:echo() {
	vmsg "$@"
}

vdie() {
	if [[ $DEBUG ]]; then
		lib:msg "$*" error >&2
	else
		printf "%s\n" "$progname: $*" >&2
	fi
	exit 1
}

vmsg() {
	if [[ $DEBUG ]]; then
		lib:msg "$*" info
	else
		printf "%s\n" "$progname: $*"
	fi
}

msg() {
	if [[ $DEBUG ]]; then
		lib:msg "$*" info
	else
		printf "%s\n" "$*"
	fi
}

# lib:backtrace
#
# Print a call trace.

lib:backtrace() {
	local -i i=${1:-1}
	printf "%s[%s]: call stack:\n" "$progname" "$$"
	for (( 1; i <= ${#BASH_SOURCE[@]}; i++ )); do
		printf "%s[%s]:     %s:%s: %s -> %s\n" \
			"$progname" "$$" \
			"${BASH_SOURCE[i]:-???}" "${BASH_LINENO[i-1]}" \
			"${FUNCNAME[i]:-(no func)}" "${FUNCNAME[i-1]}"
	done
} >&2

## Log levels

# As lib.bash is oriented towards interactive scripts, there are additional
# levels which are mostly the same as VERBOSE or INFO but with different
# graphical appearance.

# LIB.BASH	SHOWN	FORMAT	LOG4J	PYTHON
# -------------	-------	-------	-------	-------
# trace		debug2	prefix	DEBUG	debug
# debug		debug	prefix	DEBUG	debug
# (TODO: missing verbose log, aka python info)
# info		!quiet	plain	-	-
# log		!quiet	decorat	-	-
# log2		!quiet	decorat	-	-
# warning	always	prefix	WARN	warning
# error		always	prefix	ERROR	error
# fatal		always	prefix	FATAL	critical

declare -A _log_color=(
	[trace]='\e[36m'
	[debug]='\e[96m'
	[info]='\e[1;34m'
	[log]='\e[1;32m'
	[log2]='\e[1;35m'
	[warning]='\e[1;33m'
	[error]='\e[1;31m'
	[fatal]='\e[1;31m'
)

declare -A _log_fprefix=(
	[log]='~~'
	[log2]='=='
	[fatal]='error:'
)

declare -A _log_fcolor=(
	[log]='\e[38;5;10m'
	[log2]='\e[35m'
)

declare -A _log_mcolor=(
	[log2]='\e[1m'
)

lib:trace() {
	local color= reset=
	if [[ -t 1 ]]; then
		color=${_log_color[trace]} reset='\e[m'
	fi
	if [[ $DEBUG ]] && (( DEBUG >= 2 )); then
		printf "%s[%s]: ${color}trace (%s):${reset} %s\n" \
			"$progname" "$$" "${FUNCNAME[1]}" "$*"
	fi >&2
}

debug() {
	local color= reset=
	if [[ -t 1 ]]; then
		color=${_log_color[debug]} reset='\e[m'
	fi
	if [[ $DEBUG ]]; then
		printf "%s[%s]: ${color}debug (%s):${reset} %s\n" \
			"$progname" "$$" "${FUNCNAME[1]}" "$*"
	fi >&2
}

info() {
	lib:msg "$*" info
}

lib:info() {
	lib:msg "$*" info
}

lib:log() {
	lib:msg "$*" log
}

log2() {
	lib:msg "$*" log2
	lib:settitle "$progname: $*"
}

warn() {
	lib:msg "$*" warning
	if (( DEBUG > 1 )); then lib:backtrace; fi
	(( ++warnings ))
} >&2

err() {
	lib:msg "$*" error
	if (( DEBUG > 1 )); then lib:backtrace; fi
	! (( ++errors ))
} >&2

die() {
	local r=1
	if [[ $1 =~ ^-?[0-9]+$ ]]; then r=${1#-}; shift; fi
	lib:msg "$*" fatal
	if (( DEBUG > 1 )); then lib:backtrace; fi
	exit $r
} >&2

lib:crash() {
	lib:msg "BUG: $*" fatal >&2
	lib:backtrace 2 >&2
	exit 3
}

# getopts

usage() {
	# Placeholder (to be overridden by programs)
	false
}

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

lib:die_getopts() {
	debug "opt '$OPT', optarg '$OPTARG', argv[0] '${BASH_ARGV[0]}'"
	case $OPT in
	    "?")
		if [[ $OPTARG == "?" ]] ||
		   [[ $OPTARG == "-" && ${BASH_ARGV[0]} == "--help" ]]; then
			usage || lib:crash "help text not available"
			exit 0
		elif [[ $OPTARG ]]; then
			lib:msg "unknown option '-$OPTARG'" fatal
			usage || true
			exit 2
		else
			lib:crash "incorrect options specified for getopts"
		fi;;
	    ":")
		die 2 "missing argument to '-$OPTARG'";;
	    *)
		lib:crash "unhandled option '-$OPT${OPTARG:+ }$OPTARG'";;
	esac
}

# obsolete

notice() {
	vmsg "$*" >&2
	DEBUG=2 lib:msg "BUG: obsolete function notice() used" warning >&2
	DEBUG=2 lib:backtrace 2 >&2
}

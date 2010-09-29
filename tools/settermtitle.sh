#!/bin/bash
usage() {
	echo "usage: settermtitle [-e] <title>" >&2
	exit 2
}

titlestring() {
	case ${TERM:-dumb} in
	screen*)
		printf %s "${ESC}k%s${ST}";;
	xterm*|kterm*|Eterm*|rxvt*|cygwin)
		printf %s "${ESC}];%s${BEL}";;
	vt300*)
		printf %s "${ESC}]21;%s${ST}";;
	*)
		echo "error: unknown terminal '$TERM'" >&2;;
	esac;
}

ESC='\e' ST='\e\\' BEL='\007'

if getopts "e" OPT "$@"; then
	case $OPT in
	e)	ESC='\\e' ST='\\e\\\\' BEL='\\007';;
	\?)	usage;;
	esac
fi

title=${!OPTIND}
[[ $title ]] || usage

printf "$(titlestring)" "$title"

#!/bin/sh

if [ ! "$_DYM" ] && [ -t 1 ] && [ $# -eq 2 ] && [ -f "$1" ] && [ ! -f "$2" ]; then
	read -n 1 -p "Did you mean 'mv' again? " REPLY
	if [ "$REPLY" = "y" ]; then
		echo "eah, I suck"
		echo "mv \"$1\" \"$2\""
		mv -v "$@"
		exit
	else
		echo ""
	fi
fi

export _DYM=1

exec /usr/bin/vim "$@"

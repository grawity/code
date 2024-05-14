#!/bin/sh
if [ -x /usr/bin/nvim ]; then
	exec /usr/bin/nvim "$@"
else
	echo "$0: nvim not found" >&2
	exec /usr/bin/vim "$@"
fi

#!bash

progname=${0##*/}

log() {
	echo "* $*"
}

warn() {
	echo "! $*" >&2
	return 0
}

err() {
	echo "error: $*" >&2
	return 1
}

die() {
	err "$@"
	exit 1
}

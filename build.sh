#!/usr/bin/env bash
set -x
set -e

BASEDIR="$HOME/code"

SYS="$HOSTTYPE-$OSTYPE"

OBJDIR="$BASEDIR/obj/bin.$SYS"
SYSDIR="$BASEDIR/obj/sys.$HOSTNAME"

# ensure $OBJDIR and $SYSDIR

mkdir -p "$OBJDIR"

if [ -e "$SYSDIR" ] && [ ! -L "$SYSDIR" ]; then
	echo "removing existing sysdir: $SYSDIR"
	rm -rvf "$SYSDIR"
fi

ln -nsf "bin.$SYS" "$SYSDIR"

#

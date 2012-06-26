#!/usr/bin/env bash
set -e
: ${SRCDIR:=~/src}
: ${LOCAL:=~/.local}
: ${CONFIG:=~/.config}

# download

mkdir -p "$SRCDIR" && cd "$SRCDIR"
curl 'http://swtch.com/plan9port/unix/mk-with-libs.tgz' \
	-o mk-with-libs.tgz -z mk-with-libs.tgz
tar xzf mk-with-libs.tgz

# build

cd "mk"
make PREFIX="$LOCAL"

# install

make PREFIX="$LOCAL" install

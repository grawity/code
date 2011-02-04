#!/bin/sh
if krb5-config --version | grep -qs "^heimdal "; then
	make CFLAGS="-DHEIMDAL"
else
	make
fi

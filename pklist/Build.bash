#!/bin/bash

CC=gcc
CFLAGS=(-Wall)
LIBS=(-lkrb5)

if krb5-config --version | grep -qs "^heimdal "; then
	CFLAGS+=(-DHEIMDAL)
fi

IN=(pklist.c)
OUT=pklist
$CC "${CFLAGS[@]}" -o "$OUT" "${IN[@]}" "${LIBS[@]}"

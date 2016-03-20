#!/bin/sh

imgur "$@" ||
uguu "$@" ||
upload -0 -d cap -s 's/\.temp//' "$@" ||
{ echo "all uploaders failed" >&2; exit 1; }

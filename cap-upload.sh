#!/bin/sh

exec imgur "$@"
#exec upload -0 -d cap -s 's/\.temp//' "$@"
exec uguu "$@"
#exec pomf "$@"

echo "all uploaders failed" >&2; exit 1

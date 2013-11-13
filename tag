#!/bin/bash
# tag - common MP3 tag manipulation tasks

. lib.bash || exit

case $1 in
	fix)
		log "Converting to v2.4"
		eyeD3 -Q --to-v2.4 "${@:2}"
		log "Removing ID3v1"
		eyeD3 -Q --remove-v1 "${@:2}"
		log "Removing comments and lyrics"
		eyeD3 -Q --remove-all-{comments,lyrics} "${@:2}"
		log "Converting to UTF-8"
		eyeD3 -Q --encoding utf8 --force-update "${@:2}"
		log "Forcing reindex"
		for file in "${@:2}"; do
			tracker-control -f "$file"
		done
		;;
	rename)
		eyeD3 --rename="$HOME/Music/%A/%a/%n. %t" "${@:2}"
		;;
	*)
		die "unknown command '$1'"
		;;
esac

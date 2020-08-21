#!/usr/bin/env bash
# tag - common MP3 tag manipulation tasks

. lib.bash || exit

cmd=$1; shift

case $cmd in
	fix)
		log "Converting to v2.4"
		eyeD3 -Q --to-v2.4 "$@"
		log "Removing ID3v1"
		eyeD3 -Q --remove-v1 "$@"
		log "Removing comments and lyrics"
		eyeD3 -Q --remove-all-{comments,lyrics} "$@"
		log "Converting to UTF-8"
		eyeD3 -Q --encoding utf8 --force-update "$@"
		if tracker daemon --list-miners-running | grep -qs '\.Files$'; then
			log "Forcing tracker reindex"
			for file in "$@"; do
				tracker reset -f "$file"
			done
		else
			debug "skipping reindex, tracker Files miner not running"
		fi
		;;
	to-2.3|to-2.4)
		e=${cmd#to-}
		log "Converting tags to v$e"
		eyeD3 -Q --force-update --to-v$e "$@"
		;;
	to-utf8|to-utf16)
		e=${cmd#to-}
		log "Converting tags to $e"
		eyeD3 -Q --force-update --encoding $e "$@"
		;;
	no-v1)
		log "Removing ID3v1"
		mid3v2 --delete-v1 "$@"
		;;
	etouch)
		log "Updating tags (removes unsync frames, etc.)"
		eyeD3 -Q --force-update "$@"
		;;
	mtouch)
		mid3v2 --convert "$@"
		;;
	pony)
		mutagen-pony .
		;;
	raw)
		mid3v2 --list-raw "$@"
		;;
	rename)
		eyeD3 --rename="$HOME/Music/%A/%a/%n. %t" "$@"
		;;
	*)
		die "unknown command '$cmd'"
		;;
esac

#!/usr/bin/env bash

. lib.bash || exit

origin() { attr -q -g 'xdg.origin.url' "$1"; } 2>/dev/null

referer() { attr -q -g 'xdg.referrer.url' "$1"; } 2>/dev/null

put() {
	local src=$1 dst=${2%/}
	local srcbase=${src##*/} ctr=0
	local srcname=${srcbase%.*} srcext=${srcbase##*.}
	local dstx=${dst/#"$HOME/"/'~/'}
	debug "moving to '$dst'"
	while [[ -e "$dst/$srcbase" ]]; do
		if cmp "$src" "$dst/$srcbase"; then
			printf '\e[34m%s\e[m ‘%s’ in ‘%s’\n' "duplicate:" "$src" "$dstx"
			rm -f "$src"
			return
		fi
		srcbase=$srcname.$((++ctr)).$srcext
	done
	if mv -i "$src" "$dst/$srcbase"; then
		printf '\e[32m%s\e[m ‘%s’ → ‘%s’\n' "sorted:" "$src" "$dstx"
	fi
}

cd ~/Downloads

shopt -s nullglob

for file in *.jpg *.jpeg *.png *.gif; do
	debug "file: $file"

	ref=$(referer "$file")
	debug "-- referer: ${ref:-none}"
	if [[ ! $ref ]]; then
		ref=$(origin "$file")
		debug "-- origin: ${ref:-none}"
	fi

	case $ref in
	"")
		printf '\e[33m%s\e[m %s\n' "no-origin:" "$file"; continue;;
	http://imgur.com/r/*)
		ref=${ref#http://imgur.com};;
	http://www.*)
		ref=http://${ref#http://www.};;
	https://www.*)
		ref=http://${ref#https://www.};;
	https://*)
		ref=http:${ref#https:};;
	esac

	debug "-- canonical: $ref"

	case $ref:$file in
	*:*\[Vocaloid\]*)
		put "$file" ~/Pictures/Art/Vocaloid/;;
	/r/awwnime/*)
		put "$file" ~/Pictures/Art/r-awwnime/;;
	/r/bdsm/*|/r/bdsmgw/*)
		put "$file" ~/Pictures/Porn/;;
	/r/pantsu/*|/r/sukebei/*)
		put "$file" ~/Pictures/Ero/;;
	/r/ecchi/*|/r/hentai/*|http://gelbooru.com/*)
		put "$file" ~/Pictures/Ero/;;
	http://derpiboo.ru/*)
		put "$file" ~/Pictures/Art/fanart/'My Little Pony'/;;
	*)
		printf '\e[33m%s\e[m %s\n' "unknown:" "\"$file\" from $ref";;
	esac
done

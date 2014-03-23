#!/usr/bin/env bash

origin() { attr -q -g 'xdg.origin.url' "$1"; } 2>/dev/null

referer() { attr -q -g 'xdg.referrer.url' "$1"; } 2>/dev/null

put() {
	local src=$1 dst=${2%/}
	local srcbase=${src##*/} ctr=0
	local srcname=${srcbase%.*} srcext=${srcbase##*.}
	while [[ -e "$dst/$srcbase" ]]; do
		if cmp "$src" "$dst/$srcbase"; then
			printf '\e[34m%s\e[m ‘%s’\n' "duplicate:" "$src"
			rm -f "$src"
			return
		fi
		srcbase=$srcname.$((++ctr)).$srcext
	done
	mv -i "$src" "$dst/$srcbase"
	printf '\e[32m%s\e[m ‘%s’ → ‘%s’\n' "sorted:" "$src" "${dst/#$HOME/~}"
}

cd ~/Downloads

shopt -s nullglob

for file in *.jpg *.jpeg *.png *.gif; do
	ref=$(referer "$file")
	if [[ ! $ref ]]; then
		ref=$(origin "$file")
	fi
	case $ref in
	"")
		printf '\e[33m%s\e[m %s\n' "empty:" "$file"; continue;;
	http://imgur.com/r/*)
		ref=${ref#http://imgur.com};;
	http://www.*)
		ref=http://${ref#http://www.};;
	https://www.*)
		ref=http://${ref#https://www.};;
	https://*)
		ref=http:${ref#https:};;
	esac
	case $ref in
	/r/awwnime/*)
		put "$file" ~/Pictures/r-awwnime/;;
	/r/bdsm/*|/r/bdsmgw/*)
		put "$file" ~/Pictures/Porn;;
	/r/pantsu/*)
		put "$file" ~/Pictures/Ero/;;
	/r/ecchi/*|/r/hentai/*|http://gelbooru.com/*)
		put "$file" ~/Pictures/Ero/;;
	*)
		printf '\e[33m%s\e[m %s\n' "unknown:" "\"$file\" from $ref";;
	esac
done

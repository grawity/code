#!bash

tuple=i386-linux-gnu
paths=(
	/lib
	/lib/$tuple
	/usr/lib
	/usr/lib/$tuple
)

resolve() {
	if [[ $1 == /* ]]; then
		echo "$1"
		return 0
	fi
	local dir
	for dir in "${paths[@]}"; do
		if [[ -e $dir/$1 ]]; then
			echo "$dir/$1"
			return 0
		fi
	done
	return 1
}

readconf() {
	:
}

readconf /etc/ld.so.conf

dodeps() {
	local file=$1 nest=$2
	(( nest > 3 )) && return
	local indent=$(( nest * 4 ))
	printf '%*s\e[1m%s\e[m -> %s\n' "$indent" "" "${file##*/}" "$file"
	local findent=$(( indent + 4 ))
	local dynsection=0
	objdump -p "$file" |
	awk '$1 == "NEEDED" {print $2}' |
	while read file; do
		[[ $file == 'ld-linux'* ]] && return
		[[ $file == 'libc.so'* ]] && return
		if path=$(resolve "$file"); then
			dodeps "$path" "$[nest+1]"
		else
			printf '%*s%s\n' "$findent" "" "$file"
		fi
	done
}

dodeps "$1" 0

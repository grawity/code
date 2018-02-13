#!/bin/bash

# depends on 'arpaname' from bind-tools

ip2zone() {
	local name addr plen nbits nibble n
	
	name=$1
	if [[ $name != */* ]]; then
		return
	fi
	addr=${name%/*}
	plen=${name#*/}
	name=$(arpaname "$addr") || return
	if [[ $addr == *:* ]]; then
		nbits=128 nibble=4
	else
		nbits=32 nibble=8
	fi
	if (( plen < nibble || plen > nbits )); then
		echo "error: prefix length /$plen is invalid"
		return
	fi
	if (( plen % nibble != 0 )); then
		echo "error: $addr/$plen cannot be delegated directly"
		return
	fi
	for (( nbits; nbits > plen; nbits -= nibble )); do
		if [[ $name != 0.* ]]; then
			echo "error: $addr is longer than /$plen"
			return
		fi
		name=${name#*.}
	done
	name=${name,,}
	echo $name
}

for name; do
	ip2zone "$name"
done

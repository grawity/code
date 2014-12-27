#!/usr/bin/env bash

if [[ -t 1 ]]; then
	c=('\e[1;30m' '\e[32m' '\e[34m' '\e[35m' '\e[36m' '\e[m')
else
	c=()
fi

dev=${1:-sda}
dev=${dev#/dev/}

echo "#!/bin/sh -ex"

for part in /sys/class/block/${dev}[0-9]*; do
	num=$(<$part/partition)
	start=$(<$part/start)
	size=$(<$part/size)
	end=$((start+size-1))
	echo -e "\n${c[0]}# partition ${c[1]}$num${c[0]}, start ${c[2]}$start${c[0]}, size ${c[3]}$size${c[0]}, end ${c[4]}$end${c[0]}${c[5]}\n"
	echo "sgdisk /dev/$dev --new=$num:$start:$end"
	#echo "parted /dev/$dev mkpart primary $start $end"
done

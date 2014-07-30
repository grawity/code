#!/usr/bin/env bash

dev=${1:-sda}

dev=${dev#/dev/}

echo "set -e -x"

for part in /sys/class/block/${dev}[0-9]*; do
	partnum=$(<$part/partition)
	start=$(<$part/start)
	size=$(<$part/size)
	end=$((start+size-1))
	echo -e "\n# partition \e[32m$partnum\e[m, start \e[34m$start\e[m, size \e[35m$size\e[m, end \e[36m$end\e[m"
	echo "sgdisk /dev/$dev --new=$partnum:$start:$end"
	#echo "parted /dev/$dev mkpart primary $start $end"
done

#!/usr/bin/env bash

get_best_dev() {
	declare -- best_dev= line=
	declare -i best_metric=0

	while read line; do
		declare -a argv=($line)
		declare -i argc=${#argv[@]}
		if [[ ${argv[0]} == default ]]; then
			declare -- this_dev=
			declare -i this_metric=0 i=1
			while (( i < argc )); do
				case ${argv[i]} in
				metric) this_metric=${argv[i+1]};;
				dev)    this_dev=${argv[i+1]};;
				esac
				(( i += 2 ))
			done
			if [[ ! $best_dev ]] || (( this_metric < best_metric )); then
				best_dev=$this_dev
				best_metric=$this_metric
			fi
		fi
	done < <(ip -4 route)

	echo $best_dev
}

time get_best_dev

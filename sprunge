#!/bin/bash
if [ -z "$1" ]; then
	cat | curl -s -F "sprunge=<-" http://sprunge.us/
else
	for file; do
		echo "$file -> $( curl -s -F "sprunge=<-" http://sprunge.us/ )"
	done
fi

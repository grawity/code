#!/usr/bin/env bash

err() { echo "$*" >&2; false; }
die() { err "$@"; exit; }

pushover_user=$(getnetrc -df %p api.pushover.net)
pushover_token=$(getnetrc -df %p api.pushover.net shove)

[[ $pushover_user ]]  || die "Pushover user ID missing"
[[ $pushover_token ]] || die "Pushover app token missing"

args=(-F "user=$pushover_user"
      -F "token=$pushover_token")

args+=(-F "message=$1")

if [[ $2 ]]; then
	args+=(-F "title=$2")
fi

curl -s "${args[@]}" https://api.pushover.net/1/messages.json

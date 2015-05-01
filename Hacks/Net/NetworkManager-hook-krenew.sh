#!/usr/bin/env bash

if [ "$2" = "up" ]; then
	pkill -ALRM -x krenew
	pkill -ALRM -x k5start
fi

exit


_owner() { stat -c '%u:%g' "$1"; }

_process() {
	(export KRB5CCNAME="$2"
	chpst -u :$1 bash -c "_process_as_user") &
}

_process_as_user() {
	exec {fd}<&0
	pklist | {
		mainprinc= mainrealm= mainstart= mainend= mainrenew= mainflags=
		while IFS=$'\t' read -r type client server start end renew flags _; do
			if [[ $type == 'principal' ]]; then
				mainprinc=$client
				mainrealm=${mainprinc##*@}
			elif [[ $type == 'ticket' ]] &&
			     [[ $client == "$mainprinc" ]] &&
			     [[ $server == "krbtgt/$mainrealm@$mainrealm" ]]; then
			     	mainstart=$start
				mainend=$end
				mainrenew=$renew
				mainflags=$flags
			fi
		done
		exec <&$fd-
		if [[ ! $mainprinc ]] || (( ! $mainstart )); then
			continue
		elif (( mainend < NOW )); then
			echo "skipping $mainprinc (expired)"
		elif [[ $mainflags == *R* ]]; then
			totallife=$(( mainend - mainstart ))
			currentlife=$(( mainend - NOW ))
			echo "renewing $mainprinc ($currentlife seconds left out of $totallife)"
			kinit -R
		else
			echo "skipping $mainprinc (not renewable)"
		fi
	}
}

export PATH="$PATH:/usr/local/bin"

export NOW=$(date +%s)

export -f _process_as_user

shopt -s nullglob

if [ "$2" = "up" ]; then
	for file in /run/user/*/krb5cc/tkt*; do
		_process $(_owner "$file") "DIR::$file"
	done

	for file in /tmp/krb5cc_[0-9]*; do
		_process $(_owner "$file") "FILE:$file"
	done
fi |& systemd-cat -t "NetworkManager/krenew"

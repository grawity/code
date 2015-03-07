#!/usr/bin/env bash

if [[ ! -t 0 ]]; then
	echo "something on $HOSTNAME is still using the old rwhod.sh!" \
		| logger -s -p user.warn -n 'wolke.nullroute.eu.org' &
fi

OLD_DIR=$(dirname "$0")

if (( $UID > 0 )); then
	RWHO_DIR=$HOME/lib/rwho
else
	RWHO_DIR=/cluenet/rwho
fi

RWHO_SCRIPT="$RWHO_DIR/agent-linux/rwho-agent.sh"

case $1 in
update)
	echo "new rwho location: $RWHO_DIR"
	if [[ -d $RWHO_DIR ]]; then
		exec "$RWHO_SCRIPT" git-update
	else
		echo "cloning git repository"
		mkdir -p "$(dirname "$RWHO_DIR")"
		git clone "git://github.com/grawity/rwho.git" "$RWHO_DIR"
		cp -a "$OLD_DIR/config.php" "$RWHO_DIR"

		echo "restarting rwho"
		"$RWHO_SCRIPT" restart

		#echo "installing cronjob"
		#{ crontab -l;
		#  echo "@daily	${RWHO_DIR/#$HOME/~}/rwhod.sh git-update";
		#  } | crontab -
	fi
	;;
*)
	exec "$RWHO_SCRIPT" "$@"
	;;
esac

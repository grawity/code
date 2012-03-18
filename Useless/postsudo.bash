# source this in bash

_postfixsudo() {
	if [[ $BASH_COMMAND == *' NOW' ]]; then
		eval "sudo ${BASH_COMMAND% NOW}" && false
	else
		true
	fi
}

shopt -s extdebug
trap "_postfixsudo" DEBUG

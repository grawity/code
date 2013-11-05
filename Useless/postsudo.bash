# source this in bash

_p() case $BASH_COMMAND in *' NOW') eval sudo ${BASH_COMMAND% *} && false;; *) true; esac; shopt -s extdebug; trap _p DEBUG

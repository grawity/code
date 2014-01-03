# source this in bash

#_p() case $BASH_COMMAND in *' NOW') eval sudo ${BASH_COMMAND% *} && false; esac; shopt -s extdebug; trap _p DEBUG

shopt -s extdebug; trap 'case $BASH_COMMAND in *" NOW") eval sudo ${BASH_COMMAND% *} && false; esac' DEBUG

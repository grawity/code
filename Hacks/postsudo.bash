# source this in bash

shopt -s extdebug; trap 'case $BASH_COMMAND in *" NOW") eval sudo ${BASH_COMMAND% *}; false; esac' DEBUG

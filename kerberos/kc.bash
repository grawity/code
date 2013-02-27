#!bash
# kc.bash - Kerberos credential cache juggler
#
# Must be 'source'd (ie. from bashrc) in order for cache switching to work.

kc() {
	local ev; { ev=$(~/code/kerberos/kc.pl "$@" 3>&1 >&4); } 4>&1 && eval "$ev"
}

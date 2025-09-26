#!bash
# kc.sh -- Kerberos credential cache juggler (wrapper script)
#
# Must be sourced (ie. from bashrc) in order for cache switching to work.

kc() {
	local ev; { ev=$(command kc "$@" 3>&1 >&4); } 4>&1 && eval "$ev"
}

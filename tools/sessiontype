#!/usr/bin/env bash
# Print the current session's parent process name.

#pid=${1:-$(ps -p $$ -o "ppid=")}
pid=${1:-$$}

# our Session ID (= PID of whatever started the session)
sid=$(echo $(ps -p $pid -o "sess="))
(( sid )) || exit 1

# session starter's Parent PID (usually sshd or in.telnetd)
sppid=$(echo $(ps -p $sid -o "ppid="))
(( sppid )) || exit 1

cmd=$(echo $(ps -p $sppid -o "cmd="))
case $cmd in
	"sshd: "*)
		conn=ssh ;;
	"in.telnetd: "*)
		conn=telnet ;;
	"SCREEN")
		conn=screen ;;
	"tmux"|"tmux "*)
		conn=tmux ;;
	gnome-terminal|konsole|xterm|yakuake)
		conn=x11 ;;
	*)
		conn=-
esac

printf '%s\t%d\t%s\n' "$conn" "$sppid" "$cmd"

#!/bin/sh
# Print the current session's parent process name.

#pid=${1:-$(ps -p $$ -o "ppid=")}
pid=${1:-$$}

# our Session ID (= PID of whatever started the session)
sid=$(ps -p $pid -o "sess=")
# session starter's Parent PID (usually sshd or in.telnetd)
sppid=$(ps -p $sid -o "ppid=")

ps -p $sppid -o "cmd="
#ps -p $sppid -o "uid,pid,ppid,cmd"
